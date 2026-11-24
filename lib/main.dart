import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'process_labels.dart';
import 'paper_theme.dart';
import 'notebook_motion.dart';
import 'paper_surface.dart';
import 'tree_preview.dart';
import 'sketch_icons.dart';
import 'memo_tree.dart';
import 'handwriting_pad.dart';
import 'spotlight_tutorial.dart';
import 'app_strings.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';

void registerNotebookFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('licenses/Xiaolai-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Xiaolai'], text);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerNotebookFontLicense();
  final store = Store();
  await store.open();
  runApp(
    MemoApp(
      store,
      initialTheme: await store.themeName(),
      initialLanguage: await store.languageName(),
    ),
  );
}

class MemoApp extends StatefulWidget {
  const MemoApp(
    this.store, {
    super.key,
    this.initialTheme = 'lavender',
    this.initialLanguage = 'system',
  });
  final Store store;
  final String initialTheme;
  final String initialLanguage;
  @override
  State<MemoApp> createState() => _MemoAppState();
}

class _MemoAppState extends State<MemoApp> {
  late String theme = widget.initialTheme;
  late String language = widget.initialLanguage;
  Future<void> setLanguage(String name) async {
    await widget.store.setLanguageName(name);
    if (mounted) setState(() => language = name);
  }

  Future<void> setTheme(String name) async {
    await widget.store.setThemeName(name);
    if (mounted) setState(() => theme = name);
  }

  Future<void> reloadTheme() async {
    final name = await widget.store.themeName();
    final lang = await widget.store.languageName();
    if (mounted)
      setState(() {
        theme = name;
        language = lang;
      });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GONDUT',
    localizationsDelegates: [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      quill.FlutterQuillLocalizations.delegate,
    ],
    supportedLocales: [
      Locale('ko'),
      Locale('en'),
      Locale('ja'),
      Locale('zh'),
      Locale('es'),
    ],
    locale: language == 'system' ? null : Locale(language),
    localeListResolutionCallback: (locales, supported) {
      final code = locales?.firstOrNull?.languageCode;
      if (const {'ko', 'en', 'ja', 'zh', 'es'}.contains(code))
        return Locale(code!);
      return Locale('en');
    },
    theme: paperTheme(theme),
    home: Home(
      widget.store,
      themeName: theme,
      onThemeChanged: setTheme,
      languageName: language,
      onLanguageChanged: setLanguage,
      onThemeRestored: reloadTheme,
    ),
  );
}

class Home extends StatefulWidget {
  const Home(
    this.store, {
    super.key,
    this.themeName = 'lavender',
    this.languageName = 'system',
    this.onLanguageChanged,
    this.onThemeChanged,
    this.onThemeRestored,
  });
  final Store store;
  final String themeName;
  final String languageName;
  final Future<void> Function(String)? onLanguageChanged;
  final Future<void> Function(String)? onThemeChanged;
  final Future<void> Function()? onThemeRestored;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final tutorialCreateKey = GlobalKey();
  final tutorialMenuKey = GlobalKey();
  int tutorialStep = -1;
  int tab = 0;
  String query = '';
  bool inbox = false;
  int? connecting;
  final TransformationController graphTransform = TransformationController();
  int refreshVersion = 0;
  List<Map<String, Object?>> memos = [], nodes = [], edges = [];
  Map<int, List<Map<String, Object?>>> memoTrees = {};
  List<Map<String, Object?>> folders = [];
  int? currentFolder;
  @override
  void initState() {
    super.initState();
    refresh();
    widget.store
        .tutorialComplete()
        .then((complete) {
          if (mounted && !complete) setState(() => tutorialStep = 0);
        })
        .catchError((_) {});
  }

  Future<void> finishTutorial() async {
    if (mounted) setState(() => tutorialStep = -1);
    try {
      await widget.store.setTutorialComplete();
    } catch (_) {
      /* Retry on next launch. */
    }
  }

  Future<void> nextHomeTutorial() async {
    if (tutorialStep == 0) {
      setState(() => tutorialStep = 1);
      return;
    }
    setState(() => tutorialStep = -1);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Editor(_TutorialStore(), 0, '', tutorial: true),
      ),
    );
    await finishTutorial();
  }

  Future<void> refresh() async {
    final version = ++refreshVersion;
    final m = await widget.store.memos(query);
    final f = await widget.store.folders();
    final trees = await Future.wait(
      m.map((row) => widget.store.branches(row['id'] as int)),
    );
    final n = await widget.store.nodes();
    final e = await widget.store.edges();
    if (mounted && version == refreshVersion) {
      setState(() {
        memos = m;
        folders = f;
        memoTrees = {
          for (var i = 0; i < m.length; i++) m[i]['id'] as int: trees[i],
        };
        nodes = n.map((row) => Map<String, Object?>.from(row)).toList();
        edges = e;
      });
    }
  }

  @override
  void dispose() {
    graphTransform.dispose();
    super.dispose();
  }

  Future<void> edit([Map<String, Object?>? memo, String? newKind]) async {
    final id = memo == null
        ? await widget.store.addMemo('')
        : memo['id'] as int;
    if (memo == null) {
      await widget.store.setMemoKind(id, newKind ?? 'note');
      if (currentFolder != null)
        await widget.store.moveMemoToFolder(id, currentFolder);
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Editor(
          widget.store,
          id,
          memo?['text'] as String? ?? '',
          initialRichText: memo?['rich_text'] as String?,
          initialTitle: memo?['title'] as String?,
          initialTree: (memo?['kind'] ?? newKind) == 'graph',
        ),
      ),
    );
    await refresh();
  }

  Future<void> createItem() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add_outlined),
              title: Text(tr(c, '일반 메모')),
              onTap: () => Navigator.pop(c, 'note'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(tr(c, '나무 그래프')),
              onTap: () => Navigator.pop(c, 'graph'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(tr(c, '새 폴더')),
              onTap: () => Navigator.pop(c, 'folder'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice != 'folder') {
      await edit(null, choice);
      return;
    }
    var name = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, '새 폴더')),
        content: TextField(
          autofocus: true,
          maxLength: 80,
          onChanged: (v) => name = v,
          decoration: InputDecoration(hintText: tr(c, '폴더 이름')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr(c, '취소')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(c, '만들기')),
          ),
        ],
      ),
    );
    if (saved == true && name.trim().isNotEmpty) {
      await widget.store.addFolder(name);
      await refresh();
    }
  }

  Future<void> chooseFolder(int memoId) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(tr(c, '홈')), onTap: () => Navigator.pop(c, 0)),
            for (final folder in folders)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder['name'] as String),
                onTap: () => Navigator.pop(c, folder['id'] as int),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.store.moveMemoToFolder(
        memoId,
        selected == 0 ? null : selected,
      );
      await refresh();
    }
  }

  Future<void> backup() async {
    try {
      final result = await FilePicker.saveFile(
        fileName: 'memo-graph-backup.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(await widget.store.backup())),
      );
      if (result != null && mounted) message(tr(context, '백업 저장 완료'));
    } catch (_) {
      if (mounted) message(tr(context, '백업 실패'));
    }
  }

  Future<void> restore() async {
    try {
      final pick = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (pick == null) return;
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(context, '백업 복원')),
          content: Text(
            tr(context, '현재 메모와 그래프를 백업 내용으로 교체합니다. 먼저 현재 데이터를 백업하세요.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(context, '취소')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(context, '교체')),
            ),
          ],
        ),
      );
      if (yes != true) return;
      final data = utf8.decode(await pick.readAsBytes());
      await widget.store.restore(data);
      await widget.onThemeRestored?.call();
      await refresh();
      if (mounted) message(tr(context, '복원 완료'));
    } catch (_) {
      if (mounted) message(tr(context, '복원 실패'));
    }
  }

  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> showSettings() async {
    var showCharacters = await widget.store.charactersEnabled();
    if (!mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, updateDialog) => AlertDialog(
          title: Text(tr(context, '설정')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, '소인 캐릭터 표시')),
                  value: showCharacters,
                  onChanged: (value) async {
                    try {
                      await widget.store.setCharactersEnabled(value);
                      if (c.mounted) updateDialog(() => showCharacters = value);
                    } catch (_) {
                      message(tr(context, '캐릭터 설정을 저장하지 못했습니다.'));
                    }
                  },
                ),
                Divider(),
                Text(
                  tr(context, '언어'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final option in <(String, String)>[
                  ('system', tr(context, '기기 설정 따르기')),
                  ('ko', '한국어'),
                  ('en', 'English'),
                  ('ja', '日本語'),
                  ('zh', '中文（简体）'),
                  ('es', 'Español'),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.$2),
                    trailing: widget.languageName == option.$1
                        ? Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(c, 'language:${option.$1}'),
                  ),
                Divider(),
                Text(
                  tr(context, '앱 테마'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(tr(context, '마음에 드는 색을 골라 보세요.')),
                SizedBox(height: 12),
                for (final entry in themeColors.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: entry.value.$2,
                      radius: 15,
                    ),
                    title: Text(tr(context, entry.value.$1)),
                    trailing: widget.themeName == entry.key
                        ? Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(c, entry.key),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr(context, '닫기')),
            ),
          ],
        ),
      ),
    );
    if (selected != null && selected.startsWith('language:')) {
      try {
        await widget.onLanguageChanged?.call(selected.substring(9));
      } catch (_) {
        message(tr(context, '언어를 저장하지 못했습니다.'));
      }
    } else if (selected != null && widget.onThemeChanged != null) {
      try {
        await widget.onThemeChanged!(selected);
      } catch (_) {
        message(tr(context, '테마를 저장하지 못했습니다. 다시 시도해 주세요.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Scaffold(
        appBar: AppBar(
          title: Text(
            'GONDUT',
            style: TextStyle(
              fontFamily: 'GondutHand',
              fontSize: 28,
              letterSpacing: 2,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              key: tutorialMenuKey,
              onSelected: (v) {
                if (v == 'backup') {
                  backup();
                } else if (v == 'restore') {
                  restore();
                } else if (v == 'settings') {
                  showSettings();
                } else if (v == 'tutorial') {
                  setState(() => tutorialStep = 0);
                } else if (v == 'legacy') {
                  showLegacyGraph();
                } else if (v == 'licenses') {
                  showLicensePage(context: context, applicationName: 'GONDUT');
                } else {
                  showDialog<void>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(tr(context, '개인정보와 저장')),
                      content: SingleChildScrollView(
                        child: Text(
                          tr(
                            context,
                            '메모와 그래프는 기기에 저장됩니다. 앱은 계정이나 클라우드 동기화를 제공하지 않습니다.\n\n백업 파일은 암호화되지 않습니다. 앱을 삭제하면 기기 내부 기록이 삭제됩니다.\n\n운영자: J.MEN\n문의: juson082@gmail.com',
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: Text(tr(context, '닫기')),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'tutorial',
                  child: Text(tr(context, '사용 방법')),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text(tr(context, '설정 · 테마')),
                ),
                PopupMenuItem(
                  value: 'backup',
                  child: Text(tr(context, '백업 저장')),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: Text(tr(context, '백업 복원')),
                ),
                PopupMenuItem(
                  value: 'licenses',
                  child: Text(tr(context, '오픈소스 라이선스')),
                ),
                if (nodes.isNotEmpty)
                  PopupMenuItem(
                    value: 'legacy',
                    child: Text(tr(context, '이전 그래프 기록 보기')),
                  ),
                PopupMenuItem(
                  value: 'privacy',
                  child: Text(tr(context, '개인정보와 저장')),
                ),
              ],
            ),
          ],
        ),
        body: memoPage(),
        floatingActionButton: NotebookPress(
          child: FloatingActionButton.extended(
            key: tutorialCreateKey,
            onPressed: createItem,
            icon: SketchIcon('add'),
            label: Text(tr(context, '새 메모')),
          ),
        ),
      ),
      if (tutorialStep >= 0)
        Positioned.fill(
          child: SpotlightTutorial(
            target: tutorialStep == 0 ? tutorialCreateKey : tutorialMenuKey,
            radius: tutorialStep == 0 ? 32 : 24,
            message: tutorialStep == 0
                ? '새 메모에서 노트, 그래프, 폴더를 만들어요.'
                : '여기서 테마와 언어를 바꾸고 백업할 수 있어요.',
            onNext: nextHomeTutorial,
            onSkip: finishTutorial,
          ),
        ),
    ],
  );

  Future<void> showLegacyGraph() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, '이전 그래프 기록')),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(tr(context, '이전 버전의 메모 간 연결입니다. 읽기 전용으로 보관되며 백업에도 포함됩니다.')),
              SizedBox(height: 12),
              for (final node in nodes)
                ListTile(
                  title: Text(
                    (node['text'] as String).isEmpty
                        ? tr(context, '(빈 메모)')
                        : node['text'] as String,
                  ),
                  subtitle: Text(
                    '${tr(context, '연결')}: ${edges.where((e) => e['source'] == node['id']).map((e) => label(e['target'] as int)).join(', ')}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(context, '닫기')),
          ),
        ],
      ),
    );
  }

  Widget memoPage() {
    final visible = memos
        .where((m) => m['folder_id'] == currentFolder)
        .toList();
    if (currentFolder == null && folders.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          for (final folder in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder['name'] as String),
              onTap: () => setState(() => currentFolder = folder['id'] as int),
            ),
          SizedBox(
            height: visible.isEmpty ? 120 : ((visible.length + 1) ~/ 2) * 192.0,
            child: _memoGrid(visible),
          ),
        ],
      );
    }
    if (currentFolder != null)
      return Column(
        children: [
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: Text(
              folders
                      .where((f) => f['id'] == currentFolder)
                      .map((f) => f['name'] as String)
                      .firstOrNull ??
                  '',
            ),
            onTap: () => setState(() => currentFolder = null),
          ),
          Expanded(child: _memoGrid(visible)),
        ],
      );
    return _memoGrid(visible);
  }

  Widget _memoGrid(List<Map<String, Object?>> visible) => visible.isEmpty
      ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16),
              Text(tr(context, '생각을 한 장씩 모아 보세요')),
              SizedBox(height: 6),
              Text(tr(context, '새 메모를 눌러 시작해요')),
            ],
          ),
        )
      : GridView.builder(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 100),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 180,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final m = visible[index];
            final content = (m['title'] as String?)?.isNotEmpty == true
                ? m['title'] as String
                : (m['text'] as String);
            return NotebookPress(
              child: Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: branchShape(
                  'rounded',
                  BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => edit(m),
                  onLongPress: () => memoOptions(m),
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: (memoTrees[m['id']]?.isNotEmpty ?? false)
                              ? TreePreview(
                                  key: ValueKey('tree-preview-${m['id']}'),
                                  items: memoTrees[m['id']]!,
                                )
                              : Text(
                                  content.trim().isEmpty
                                      ? tr(context, '새 메모')
                                      : content.trim(),
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          (memoTrees[m['id']]?.isNotEmpty ?? false)
                              ? (content.trim().isEmpty
                                    ? tr(context, '새 메모')
                                    : content.trim())
                              : tr(context, '길게 눌러 더보기'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

  Future<void> memoOptions(Map<String, Object?> memo) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: Text(tr(context, '폴더로 이동')),
              onTap: () => Navigator.pop(c, 'move'),
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text(tr(context, '이전 초안 확인')),
              onTap: () => Navigator.pop(c, 'draft'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text(tr(context, '메모 삭제')),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'draft') {
      await showDraft(memo['id'] as int);
    }
    if (action == 'move' && mounted) await chooseFolder(memo['id'] as int);
    if (action == 'delete' && mounted) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(context, '메모 삭제')),
          content: Text(
            tr(
              context,
              '메모와 이 메모의 가지가 삭제됩니다. 이전 그래프에 배치된 메모라면 해당 노드와 연결도 함께 삭제됩니다.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(context, '취소')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(context, '삭제')),
            ),
          ],
        ),
      );
      if (yes == true) {
        await widget.store.deleteMemo(memo['id'] as int);
        await refresh();
      }
    }
  }

  Widget graphPage() => Column(
    children: [
      SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final m in memos)
              Padding(
                padding: EdgeInsets.all(4),
                child: Draggable<int>(
                  data: m['id'] as int,
                  feedback: Material(
                    child: Chip(label: Text(tr(context, '그래프에 놓기'))),
                  ),
                  child: Chip(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    label: SizedBox(
                      width: 120,
                      child: Text(
                        (m['text'] as String).isEmpty
                            ? tr(context, '(빈 메모)')
                            : m['text'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          connecting == null
              ? tr(context, '메모를 아래로 끌어 놓거나 +로 추가 · 노드를 끌어 이동')
              : tr(context, '연결할 대상 노드를 선택하세요'),
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => DragTarget<int>(
            onAcceptWithDetails: (d) async {
              final box = context.findRenderObject() as RenderBox;
              final p = graphTransform.toScene(box.globalToLocal(d.offset));
              await widget.store.addNode(
                d.data,
                p.dx.clamp(0, 1200).toDouble(),
                p.dy.clamp(0, 1200).toDouble(),
              );
              refresh();
            },
            builder: (context, candidates, rejected) => InteractiveViewer(
              transformationController: graphTransform,
              constrained: false,
              boundaryMargin: EdgeInsets.all(200),
              minScale: .4,
              maxScale: 2,
              child: SizedBox(
                width: 1400,
                height: 1400,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(1400, 1400),
                      painter: EdgesPainter(nodes, edges),
                    ),
                    for (final n in nodes)
                      Positioned(
                        left: (n['x'] as num).toDouble(),
                        top: (n['y'] as num).toDouble(),
                        child: GestureDetector(
                          onPanEnd: (d) {},
                          onPanUpdate: (d) async {
                            final scale = graphTransform.value
                                .getMaxScaleOnAxis();
                            final x =
                                (n['x'] as num).toDouble() + d.delta.dx / scale;
                            final y =
                                (n['y'] as num).toDouble() + d.delta.dy / scale;
                            setState(() {
                              n['x'] = x.clamp(0, 1250).toDouble();
                              n['y'] = y.clamp(0, 1300).toDouble();
                            });
                            await widget.store.moveNode(
                              n['id'] as int,
                              n['x'] as double,
                              n['y'] as double,
                            );
                          },
                          onTap: () async {
                            if (connecting != null) {
                              await widget.store.connect(
                                connecting!,
                                n['id'] as int,
                              );
                              connecting = null;
                              refresh();
                            } else {
                              await edit(
                                memos.firstWhere(
                                  (m) => m['id'] == n['memo_id'],
                                  orElse: () => {
                                    'id': n['memo_id'],
                                    'text': n['text'],
                                    'color': n['color'],
                                  },
                                ),
                              );
                            }
                          },
                          onLongPress: () => nodeMenu(n),
                          child: Card(
                            color: connecting == n['id']
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            child: SizedBox(
                              width: 150,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Text(
                                  (n['text'] as String).isEmpty
                                      ? tr(context, '(빈 메모)')
                                      : n['text'] as String,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: addToGraph,
              icon: Icon(Icons.add),
              label: Text(tr(context, '메모 배치')),
            ),
            TextButton(
              onPressed: connecting == null
                  ? null
                  : () => setState(() => connecting = null),
              child: Text(tr(context, '연결 취소')),
            ),
            TextButton(onPressed: edgeMenu, child: Text(tr(context, '연결 관리'))),
          ],
        ),
      ),
    ],
  );
  Future<void> addToGraph() async {
    final all = await widget.store.memos();
    if (!mounted) return;
    final id = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(tr(context, '배치할 메모')),
        children: [
          for (final m in all)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, m['id']),
              child: Text(
                (m['text'] as String).isEmpty
                    ? tr(context, '(빈 메모)')
                    : m['text'] as String,
                maxLines: 2,
              ),
            ),
        ],
      ),
    );
    if (id != null) {
      await widget.store.addNode(
        id,
        80 + nodes.length * 20.0,
        80 + nodes.length * 20.0,
      );
      refresh();
    }
  }

  Future<void> nodeMenu(Map<String, Object?> n) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(tr(context, '다른 노드에 연결')),
            onTap: () => Navigator.pop(c, 'connect'),
          ),
          ListTile(
            title: Text(tr(context, '그래프에서 제거')),
            onTap: () => Navigator.pop(c, 'remove'),
          ),
        ],
      ),
    );
    if (action == 'connect') setState(() => connecting = n['id'] as int);
    if (action == 'remove') {
      await widget.store.deleteNode(n['id'] as int);
      refresh();
    }
  }

  Future<void> edgeMenu() async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, '연결 관리')),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in edges)
                ListTile(
                  title: Text(
                    '${label(e['source'] as int)} → ${label(e['target'] as int)}',
                    maxLines: 2,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.link_off),
                    onPressed: () async {
                      await widget.store.disconnect(
                        e['source'] as int,
                        e['target'] as int,
                      );
                      if (c.mounted) Navigator.pop(c);
                      refresh();
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(context, '닫기')),
          ),
        ],
      ),
    );
  }

  Future<void> showDraft(int id) async {
    final draft = await widget.store.getDraft(id);
    if (!mounted) return;
    if (draft.isEmpty) {
      message(tr(context, '저장된 초안이 없습니다.'));
      return;
    }
    final editors = [
      for (final item in draft) TextEditingController(text: item['quote']),
    ];
    final action = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(tr(context, '음성 그래프 초안')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context, '후보를 확인하고 수정하세요. 원문 메모는 그대로 보관됩니다.')),
                Text(tr(context, '확인 후 이 메모의 나무에 가지로 추가할 수 있습니다.')),
                for (var i = 0; i < draft.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: TextField(
                      controller: editors[i],
                      maxLines: null,
                      decoration: InputDecoration(
                        labelText: tr(context, draft[i]['kind']!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(tr(context, '닫기')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, 'save'),
              child: Text(tr(context, '초안 저장')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'place'),
              child: Text(tr(context, '이 메모의 나무에 추가')),
            ),
          ],
        ),
      ),
    );
    if (action != null) {
      final edited = <Map<String, String>>[
        for (var i = 0; i < draft.length; i++)
          if (editors[i].text.trim().isNotEmpty)
            {'kind': draft[i]['kind']!, 'quote': editors[i].text.trim()},
      ];
      if (edited.isEmpty) {
        if (mounted) message(tr(context, '배치할 내용이 없습니다.'));
      } else {
        await widget.store.saveDraft(id, edited);
        if (action == 'place') {
          if (!mounted) return;
          await widget.store.putDraftIntoMemoTree(
            id,
            edited,
            categoryNames: {
              for (final label in processDraftLabels) label: tr(context, label),
            },
          );
        } else {
          if (mounted) message(tr(context, '초안을 저장했습니다.'));
        }
        await refresh();
      }
    }
    // The dialog's exit animation can still reference its text fields after pop.
    Future<void>.delayed(Duration(milliseconds: 500), () {
      for (final editor in editors) {
        editor.dispose();
      }
    });
  }

  String label(int id) =>
      (nodes.firstWhere(
            (n) => n['id'] == id,
            orElse: () => {'text': '?'},
          )['text']
          as String);
}

class Editor extends StatefulWidget {
  const Editor(
    this.store,
    this.id,
    this.initial, {
    super.key,
    this.initialRichText,
    this.initialTitle,
    this.initialTree = false,
    this.tutorial = false,
  });
  final Store store;
  final int id;
  final String initial;
  final String? initialRichText;
  final String? initialTitle;
  final bool initialTree;
  final bool tutorial;
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with WidgetsBindingObserver {
  final tutorialTitleKey = GlobalKey();
  final tutorialPaperKey = GlobalKey();
  final tutorialToolbarKey = GlobalKey();
  final tutorialGraphKey = GlobalKey();
  final tutorialInkKey = GlobalKey();
  int tutorialStep = 0;
  late quill.QuillController controller;
  final FocusNode editorFocus = FocusNode();
  final ScrollController editorScroll = ScrollController();
  Timer? timer;
  Future<void> pending = Future.value();
  bool leaving = false;
  bool tree = false;
  bool handwriting = false;
  bool invalidDocument = false;
  bool saveErrorShown = false;
  int treeRevision = 0;
  late String noteTitle = widget.initialTitle ?? '';

  Future<void> editTitle() async {
    var input = noteTitle;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(c, '제목 수정')),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(hintText: tr(c, '노트 제목')),
          onChanged: (value) => input = value,
          onFieldSubmitted: (value) => Navigator.pop(c, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(c, '취소')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, input),
            child: Text(tr(c, '저장')),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await widget.store.renameMemo(widget.id, result);
      if (mounted) setState(() => noteTitle = result.trim());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, '제목을 저장하지 못했습니다. 다시 시도해 주세요.'))),
        );
    }
  }

  @override
  void initState() {
    super.initState();
    tree = widget.initialTree;
    WidgetsBinding.instance.addObserver(this);
    quill.Document doc;
    try {
      if (widget.initialRichText != null) {
        doc = quill.Document.fromJson(
          jsonDecode(widget.initialRichText!) as List,
        );
      } else {
        doc = quill.Document();
        if (widget.initial.isNotEmpty) doc.insert(0, widget.initial);
      }
    } catch (_) {
      invalidDocument = true;
      doc = quill.Document();
      if (widget.initial.isNotEmpty) doc.insert(0, widget.initial);
    }
    controller = quill.QuillController(
      document: doc,
      selection: TextSelection.collapsed(offset: 0),
      readOnly: invalidDocument,
    );
    controller.addListener(scheduleSave);
  }

  void scheduleSave() {
    if (invalidDocument) return;
    timer?.cancel();
    timer = Timer(Duration(milliseconds: 400), save);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused)
      save();
  }

  void save() {
    if (invalidDocument) return;
    timer?.cancel();
    final plain = controller.document.toPlainText();
    final text = plain.endsWith('\n')
        ? plain.substring(0, plain.length - 1)
        : plain;
    final rich = jsonEncode(controller.document.toDelta().toJson());
    pending = pending
        .catchError((_) {})
        .then((_) => widget.store.saveRichMemo(widget.id, text, rich))
        .then((_) {
          saveErrorShown = false;
        });
    pending.catchError((_) {
      if (mounted && !saveErrorShown) {
        saveErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, '자동 저장하지 못했습니다. 다시 시도해 주세요.')),
            action: SnackBarAction(
              label: tr(context, '다시 시도'),
              onPressed: save,
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });
  }

  void selectMode(String mode) {
    FocusScope.of(context).unfocus();
    setState(() {
      tree = mode == 'tree';
      handwriting = mode == 'ink';
    });
  }

  Widget modeButton(String mode, IconData icon, String label, bool selected) =>
      NotebookPress(
        key: mode == 'tree'
            ? tutorialGraphKey
            : mode == 'ink'
            ? tutorialInkKey
            : null,
        child: IconButton(
          tooltip: tr(context, label),
          isSelected: selected,
          selectedIcon: SketchIcon(
            mode == 'ink' && handwriting ? 'keyboard' : mode,
          ),
          icon: SketchIcon(mode == 'ink' && handwriting ? 'keyboard' : mode),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
          onPressed: () {
            if (mode == 'ink' && tree) {
              setState(() => handwriting = !handwriting);
            } else {
              selectMode(mode == 'ink' && handwriting ? 'text' : mode);
            }
          },
        ),
      );

  String currentText() {
    final plain = controller.document.toPlainText();
    return plain.endsWith('\n') ? plain.substring(0, plain.length - 1) : plain;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller.removeListener(scheduleSave);
    controller.dispose();
    editorFocus.dispose();
    editorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WillPopScope(
    onWillPop: () async {
      if (leaving) return false;
      leaving = true;
      save();
      try {
        await pending;
        return true;
      } catch (_) {
        leaving = false;
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, '저장하지 못했습니다. 다시 시도해 주세요.'))),
          );
        return false;
      }
    },
    child: Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: InkWell(
              key: tutorialTitleKey,
              onTap: editTitle,
              borderRadius: BorderRadius.circular(8),
              child: Semantics(
                button: true,
                label: tr(context, '제목 수정'),
                child: Text(
                  noteTitle.isEmpty ? tr(context, '내 노트') : noteTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            actions: [
              modeButton(
                'text',
                Icons.edit_note_rounded,
                '글쓰기',
                !tree && !handwriting,
              ),
              modeButton('tree', Icons.device_hub_rounded, '나무 그래프', tree),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              if (invalidDocument)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    tr(
                      context,
                      '서식 데이터를 읽을 수 없어 원문을 읽기 전용으로 보여줍니다. 백업을 보관해 주세요.',
                    ),
                  ),
                ),
              Expanded(
                child: PaperSurface(
                  key: tutorialPaperKey,
                  child: tree
                      ? MemoTree(
                          key: ValueKey(treeRevision),
                          store: widget.store,
                          memoId: widget.id,
                          drawing: handwriting,
                        )
                      : handwriting
                      ? HandwritingPad(store: widget.store, memoId: widget.id)
                      : quill.QuillEditor.basic(
                          controller: controller,
                          focusNode: editorFocus,
                          scrollController: editorScroll,
                          config: quill.QuillEditorConfig(
                            padding: EdgeInsets.all(22),
                            placeholder: tr(context, '생각을 적어 보세요'),
                            autoFocus: false,
                            customStyles: quill.DefaultStyles(
                              paragraph:
                                  quill.DefaultStyles.getInstance(
                                    context,
                                  ).paragraph?.copyWith(
                                    style:
                                        quill.DefaultStyles.getInstance(
                                          context,
                                        ).paragraph!.style.copyWith(
                                          fontFamily: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.fontFamily,
                                          fontFamilyFallback: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.fontFamilyFallback,
                                          fontSize: 22,
                                          height: 1.25,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontWeight: FontWeight.normal,
                                          decoration: TextDecoration.none,
                                        ),
                                  ),
                            ),
                          ),
                        ),
                ),
              ),
              Material(
                key: tutorialToolbarKey,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      modeButton(
                        'ink',
                        handwriting ? Icons.keyboard_outlined : Icons.gesture,
                        handwriting ? '키보드 입력' : '손글씨',
                        handwriting,
                      ),
                      if (!tree && !handwriting && !invalidDocument)
                        Expanded(
                          child: TextFieldTapRegion(
                            child: quill.QuillSimpleToolbar(
                              controller: controller,
                              config: quill.QuillSimpleToolbarConfig(
                                multiRowsDisplay: false,
                                showFontFamily: true,
                                showFontSize: true,
                                showBoldButton: true,
                                showItalicButton: true,
                                showUnderLineButton: true,
                                showStrikeThrough: true,
                                showInlineCode: false,
                                showColorButton: true,
                                showBackgroundColorButton: true,
                                showClearFormat: true,
                                showAlignmentButtons: true,
                                showHeaderStyle: true,
                                showListNumbers: true,
                                showListBullets: true,
                                showListCheck: true,
                                showCodeBlock: false,
                                showQuote: true,
                                showIndent: true,
                                showLink: true,
                                showUndo: true,
                                showRedo: true,
                                showSearchButton: true,
                                showSubscript: false,
                                showSuperscript: false,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.tutorial)
          Positioned.fill(
            child: SpotlightTutorial(
              target: switch (tutorialStep) {
                0 => tutorialTitleKey,
                1 => tutorialPaperKey,
                2 => tutorialToolbarKey,
                3 => tutorialGraphKey,
                4 || 5 || 6 => tutorialPaperKey,
                _ => tutorialInkKey,
              },
              radius: switch (tutorialStep) {
                0 => 8,
                1 || 4 || 5 || 6 => 4,
                2 => 0,
                _ => 24,
              },
              insets: switch (tutorialStep) {
                1 || 4 || 5 || 6 => const EdgeInsets.fromLTRB(12, 5, 12, 8),
                _ => EdgeInsets.zero,
              },
              message: switch (tutorialStep) {
                0 => '제목을 누르면 이름을 바꿀 수 있어요.',
                1 => '여기에 생각을 적어요. 내용은 자동 저장돼요.',
                2 => '아래 도구를 옆으로 넘겨 글꼴과 서식을 바꿔요.',
                3 => '이 버튼으로 나무 그래프를 열어요.',
                4 => '빈 그래프는 한 번, 이후에는 빈 곳을 두 번 눌러 노드를 만들어요.',
                5 => '노드를 눌러 내용을 고치고, 길게 눌러 옮겨요. 가까운 노드에 연결돼요.',
                6 => '두 손가락으로 확대해요. 노드 메뉴에서 모양과 연결도 바꿀 수 있어요.',
                _ => '펜 버튼으로 손글씨와 그림을 남겨요. 소인도 획과 가지를 따라 걸어요.',
              },
              last: tutorialStep == 7,
              onSkip: () => Navigator.pop(context),
              onNext: () {
                if (tutorialStep == 7) {
                  Navigator.pop(context);
                  return;
                }
                if (tutorialStep == 3) selectMode('tree');
                setState(() => tutorialStep++);
              },
            ),
          ),
      ],
    ),
  );
}

/// The demonstration never writes to the user's notes or graph.
class _TutorialStore extends Store {
  @override
  Future<void> saveRichMemo(int id, String text, String rich) async {}
  @override
  Future<List<Map<String, Object?>>> branches(int memoId) async => [];
  @override
  Future<bool> charactersEnabled() async => false;
  @override
  Future<String?> graphInk(int id) async => null;
}

class EdgesPainter extends CustomPainter {
  EdgesPainter(this.nodes, this.edges);
  final List<Map<String, Object?>> nodes, edges;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = Colors.indigo.shade300
      ..strokeWidth = 2;
    for (final e in edges) {
      final a = nodes.where((n) => n['id'] == e['source']);
      final b = nodes.where((n) => n['id'] == e['target']);
      if (a.isNotEmpty && b.isNotEmpty) {
        c.drawLine(
          Offset(
            (a.first['x'] as num).toDouble() + 75,
            (a.first['y'] as num).toDouble() + 30,
          ),
          Offset(
            (b.first['x'] as num).toDouble() + 75,
            (b.first['y'] as num).toDouble() + 30,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant EdgesPainter old) => true;
}
