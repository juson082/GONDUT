import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'store.dart';
import 'voice.dart';
import 'local_ai.dart';
import 'paper_theme.dart';
import 'paper_surface.dart';
import 'sketch_icons.dart';
import 'memo_tree.dart';
import 'process_draft_page.dart';
import 'handwriting_pad.dart';
import 'app_strings.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  int tab = 0;
  String query = '';
  bool inbox = false;
  int? connecting;
  final TransformationController graphTransform = TransformationController();
  int refreshVersion = 0;
  List<Map<String, Object?>> memos = [], nodes = [], edges = [];
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final version = ++refreshVersion;
    final m = await widget.store.memos(query);
    final n = await widget.store.nodes();
    final e = await widget.store.edges();
    if (mounted && version == refreshVersion) {
      setState(() {
        memos = m;
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

  Future<void> edit([Map<String, Object?>? memo]) async {
    final id = memo == null
        ? await widget.store.addMemo('')
        : memo['id'] as int;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Editor(
          widget.store,
          id,
          memo?['text'] as String? ?? '',
          initialRichText: memo?['rich_text'] as String?,
        ),
      ),
    );
    await refresh();
  }

  Future<void> backup() async {
    try {
      final result = await FilePicker.saveFile(
        fileName: 'memo-graph-backup.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(await widget.store.backup())),
      );
      if (result != null && mounted) message(tr(context, '백업 저장 완료'));
    } catch (e) {
      if (mounted) message('${tr(context, '백업 실패')}: $e');
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
    } catch (e) {
      if (mounted) message('${tr(context, '복원 실패')}: $e');
    }
  }

  void message(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> showSettings() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context, '설정')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
  Widget build(BuildContext context) => Scaffold(
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
        IconButton(
          tooltip: tr(context, '음성 메모'),
          icon: SketchIcon('mic'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => VoicePage(widget.store)),
            );
            await refresh();
          },
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'backup') {
              backup();
            } else if (v == 'restore') {
              restore();
            } else if (v == 'settings') {
              showSettings();
            } else if (v == 'legacy') {
              showLegacyGraph();
            } else {
              showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr(context, '개인정보와 저장')),
                  content: SingleChildScrollView(
                    child: Text(
                      tr(
                        context,
                        '메모, 그래프, 음성 전사와 녹음은 기기에 저장됩니다. 음성 인식은 기기에서 처리되며 앱은 계정이나 클라우드 동기화를 제공하지 않습니다.\n\n백업에는 메모와 그래프가 포함되며 녹음 파일은 포함되지 않습니다. 백업 파일은 암호화되지 않습니다.\n\n앱 삭제 시 기기 내부 기록과 녹음이 삭제됩니다. 마이크 권한은 음성 녹음에 사용됩니다.\n\n운영자: J.MEN\n문의: juson082@gmail.com',
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
              value: 'settings',
              child: Text(tr(context, '설정 · 테마')),
            ),
            PopupMenuItem(value: 'backup', child: Text(tr(context, '백업 저장'))),
            PopupMenuItem(value: 'restore', child: Text(tr(context, '백업 복원'))),
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
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(),
      icon: SketchIcon('add'),
      label: Text(tr(context, '새 메모')),
    ),
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

  Widget memoPage() => memos.isEmpty
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
          itemCount: memos.length,
          itemBuilder: (context, index) {
            final m = memos[index];
            final content = (m['title'] as String?)?.isNotEmpty == true
                ? m['title'] as String
                : (m['text'] as String);
            return Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: branchShape(
                'rounded',
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                        child: Text(
                          content.trim().isEmpty
                              ? tr(context, '새 메모')
                              : content.trim(),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        tr(context, '길게 눌러 더보기'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
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
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text(tr(context, '음성 분석 초안 확인')),
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
      final analyze = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(context, '그래프 초안')),
          content: Text(tr(context, '저장된 초안이 없습니다. 이 메모를 기기에서 분석할 수 있습니다.')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(context, '닫기')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(context, '분석')),
            ),
          ],
        ),
      );
      if (analyze == true) await analyzeMemo(id);
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

  Future<void> analyzeMemo(int id) async {
    final text = await widget.store.memoText(id);
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      message(tr(context, '분석할 메모가 없습니다.'));
      return;
    }
    message(tr(context, '기기에서 분석 중입니다. 시간이 걸릴 수 있습니다.'));
    try {
      final analysis = await extractLocalDraft(text);
      await widget.store.saveGeneratedTitle(id, text, analysis.title);
      final draft = analysis.items;
      await refresh();
      if (!mounted) return;
      if (draft.isEmpty) {
        message(tr(context, '초안 후보를 찾지 못했습니다. 원문은 유지됩니다.'));
        return;
      }
      final saved = await widget.store.saveAnalysisDraft(id, text, draft);
      if (!mounted) return;
      if (!saved) {
        message(tr(context, '메모나 초안이 변경되어 분석 결과를 저장하지 않았습니다.'));
        return;
      }
      if (mounted) await showDraft(id);
    } catch (e) {
      if (mounted) message('${tr(context, '분석 실패')}: $e');
    }
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
  });
  final Store store;
  final int id;
  final String initial;
  final String? initialRichText;
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with WidgetsBindingObserver {
  late quill.QuillController controller;
  Timer? timer;
  Future<void> pending = Future.value();
  bool leaving = false;
  bool tree = false;
  bool handwriting = false;
  bool invalidDocument = false;
  bool saveErrorShown = false;
  bool generatingProcess = false;
  int treeRevision = 0;

  @override
  void initState() {
    super.initState();
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
      IconButton(
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
        onPressed: () =>
            selectMode(mode == 'ink' && handwriting ? 'text' : mode),
      );

  String currentText() {
    final plain = controller.document.toPlainText();
    return plain.endsWith('\n') ? plain.substring(0, plain.length - 1) : plain;
  }

  Future<void> useHandwritingText(String text, bool createGraph) async {
    if (invalidDocument) throw StateError('Invalid note');
    final existing = currentText();
    final insertion = '${existing.isEmpty ? '' : '\n'}$text';
    final offset = controller.document.length - 1;
    controller.replaceText(
      offset,
      0,
      insertion,
      TextSelection.collapsed(offset: offset + insertion.length),
    );
    save();
    await pending;
    if (!mounted) return;
    if (createGraph) {
      setState(() {
        handwriting = false;
        tree = true;
      });
      await generateProcessDraft(analysisSource: text);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '변환한 글을 메모에 추가했습니다.'))),
      );
    }
  }

  Future<void> generateProcessDraft({String? analysisSource}) async {
    if (generatingProcess || invalidDocument) return;
    final source = currentText();
    if (source.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, '먼저 메모에 내용을 적어 주세요.'))),
      );
      return;
    }
    setState(() => generatingProcess = true);
    try {
      save();
      await pending;
      if (!mounted) return;
      if (currentText() != source) throw StateError('메모가 변경되었습니다. 다시 시도해 주세요.');
      final analysis = await extractLocalDraft(analysisSource ?? source);
      if (!mounted) return;
      if (currentText() != source) throw StateError('메모가 변경되었습니다. 다시 시도해 주세요.');
      if (analysis.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, '원문에서 확인할 수 있는 과정 후보를 찾지 못했습니다. 직접 가지를 추가할 수 있습니다.'),
            ),
          ),
        );
        return;
      }
      final applied = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessDraftPage(
            store: widget.store,
            memoId: widget.id,
            source: source,
            items: analysis.items,
          ),
        ),
      );
      if (mounted && applied == true) {
        setState(() {
          tree = true;
          treeRevision++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, '확인한 초안을 나무에 추가했습니다. 자유롭게 수정할 수 있습니다.')),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'AI 초안을 만들지 못했습니다. 원문과 기존 가지는 보관됩니다. 메모가 길거나 변경되었는지도 확인해 주세요.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => generatingProcess = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    controller.removeListener(scheduleSave);
    controller.dispose();
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
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, '내 노트')),
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
                tr(context, '서식 데이터를 읽을 수 없어 원문을 읽기 전용으로 보여줍니다. 백업을 보관해 주세요.'),
              ),
            ),
          Expanded(
            child: PaperSurface(
              child: tree
                  ? MemoTree(
                      key: ValueKey(treeRevision),
                      store: widget.store,
                      memoId: widget.id,
                      onGenerate: generateProcessDraft,
                      generating: generatingProcess,
                    )
                  : handwriting
                  ? HandwritingPad(
                      store: widget.store,
                      memoId: widget.id,
                      onUseText: useHandwritingText,
                    )
                  : quill.QuillEditor.basic(
                      controller: controller,
                      config: quill.QuillEditorConfig(
                        padding: EdgeInsets.all(22),
                        placeholder: tr(context, '생각을 적어 보세요'),
                        autoFocus: false,
                        customStyles: quill.DefaultStyles(
                          paragraph: quill.DefaultStyles.getInstance(context)
                              .paragraph
                              ?.copyWith(
                                style: quill.DefaultStyles.getInstance(context)
                                    .paragraph!
                                    .style
                                    .copyWith(
                                      fontFamily: 'GondutHand',
                                      fontSize: 22,
                                      height: 1.25,
                                      color: Theme.of(context).colorScheme.onSurface,
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
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
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

class VoicePage extends StatefulWidget {
  const VoicePage(this.store, {super.key});
  final Store store;
  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final recorder = VoiceRecorder();
  Timer? limit;
  bool recording = false, busy = false;
  List<FileSystemEntity> recordings = [];
  String status = '녹음을 시작한 뒤 마치기를 누르세요. 음성은 기기에서 처리됩니다. 한 번에 최대 5분입니다.';
  @override
  void initState() {
    super.initState();
    loadRecordings();
  }

  Future<void> loadRecordings() async {
    final files = await recorder.recordings();
    if (mounted) setState(() => recordings = files);
  }

  @override
  void dispose() {
    limit?.cancel();
    recorder.dispose();
    super.dispose();
  }

  Future<void> start() async {
    try {
      await recorder.start();
      if (mounted) {
        setState(() {
          recording = true;
          status = tr(context, '녹음 중 (최대 5분)');
        });
        limit = Timer(Duration(minutes: 5), () {
          if (mounted && recording) stop();
        });
      }
    } catch (e) {
      if (mounted) setState(() => status = '${tr(context, '녹음 시작 실패')}: $e');
    }
  }

  Future<void> stop() async {
    limit?.cancel();
    setState(() {
      recording = false;
      busy = true;
      status = tr(context, '음성을 기기에서 인식 중입니다. 처음에는 모델 준비에 시간이 걸립니다.');
    });
    try {
      final path = await recorder.stop();
      if (path == null)
        throw StateError(
          mounted ? tr(context, '녹음 파일이 없습니다') : 'Recording file is missing',
        );
      await processRecording(path);
    } catch (e) {
      if (mounted)
        setState(
          () => status =
              '${tr(context, '처리 실패')}: $e\n${tr(context, '녹음 파일은 기기에 보관됩니다.')}',
        );
    } finally {
      await loadRecordings();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> processRecording(String path) async {
    final text = await transcribe(path);
    if (text.isEmpty)
      throw StateError(
        mounted
            ? tr(context, '인식된 텍스트가 없습니다. 녹음은 기기에 보관됩니다.')
            : 'No text recognized',
      );
    final id = await widget.store.addMemo(text);
    if (mounted)
      setState(() => status = tr(context, '원문을 저장했습니다. 기기에서 내용을 분석 중입니다.'));
    final command = parseCommand(text);
    if (command != null) {
      bool applied;
      try {
        applied = await widget.store.applyMemoTreeCommand(
          command.tree,
          command.parent,
          command.content,
          transcriptMemoId: id,
        );
      } catch (_) {
        if (mounted)
          setState(
            () =>
                status = '${tr(context, '원문을 저장했지만 가지에 추가하지 못했습니다.')}\n\n$text',
          );
        return;
      }
      if (mounted)
        setState(
          () => status =
              '${tr(context, applied ? '원문을 저장하고 지정한 가지에 추가했습니다.' : '원문을 저장했습니다. 메모 또는 가지를 확실히 찾지 못해 연결하지 않았습니다.')}\n\n$text',
        );
      return;
    }
    try {
      final analysis = await extractLocalDraft(text);
      await widget.store.saveGeneratedTitle(id, text, analysis.title);
      final draft = analysis.items;
      final saved =
          draft.isNotEmpty &&
          await widget.store.saveAnalysisDraft(id, text, draft);
      if (mounted)
        setState(
          () => status = draft.isEmpty
              ? '${tr(context, '원문을 메모에 저장했습니다. 생성된 그래프 초안이 없습니다.')}\n\n$text'
              : saved
              ? '${tr(context, '원문과 AI 초안을 저장했습니다. 메모를 길게 눌러 초안을 확인하세요.')}\n\n$text'
              : '${tr(context, '메모나 초안이 변경되어 새 분석 결과를 저장하지 않았습니다.')}\n\n$text',
        );
    } catch (e) {
      if (mounted)
        setState(
          () => status =
              '${tr(context, '원문을 저장했지만 AI 분석에 실패했습니다.')}\n$e\n\n$text',
        );
    }
  }

  Future<void> retryRecording(String path) async {
    setState(() {
      busy = true;
      status = tr(context, '저장된 녹음을 다시 인식 중입니다.');
    });
    try {
      await processRecording(path);
    } catch (e) {
      if (mounted)
        setState(
          () => status =
              '${tr(context, '처리 실패')}: $e\n${tr(context, '녹음 파일은 기기에 보관됩니다.')}',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !recording && !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, '음성 메모'))),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(context, status)),
              SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy
                    ? null
                    : recording
                    ? stop
                    : start,
                icon: Icon(recording ? Icons.stop : Icons.mic),
                label: Text(
                  recording ? tr(context, '녹음 마치기') : tr(context, '녹음 시작'),
                ),
              ),
              SizedBox(height: 24),
              Text(tr(context, '기기에 저장된 녹음')),
              for (final file in recordings)
                ListTile(
                  title: Text(file.uri.pathSegments.last),
                  subtitle: Text(tr(context, '다시 인식하면 새 메모가 생성됩니다.')),
                  onTap: busy || recording
                      ? null
                      : () => retryRecording(file.path),
                  trailing: IconButton(
                    tooltip: tr(context, '녹음 삭제'),
                    onPressed: busy || recording
                        ? null
                        : () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(tr(context, '녹음 삭제')),
                                content: Text(tr(context, '이 녹음 파일을 삭제할까요?')),
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
                              await File(file.path).delete();
                              await loadRecordings();
                            }
                          },
                    icon: Icon(Icons.delete_outline),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
