import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as mobile_sqlite;
import 'package:path/path.dart' as p;

void main() {
  late Store store;
  setUpAll(() {
    sqfliteFfiInit();
    mobile_sqlite.databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    store = Store();
    store.db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE memos(id INTEGER PRIMARY KEY, text TEXT NOT NULL, updated INTEGER NOT NULL, title TEXT, color INTEGER NOT NULL DEFAULT 4294960081, rich_text TEXT, ink TEXT)',
          );
          await db.execute(
            'CREATE TABLE nodes(id INTEGER PRIMARY KEY, memo_id INTEGER NOT NULL REFERENCES memos(id) ON DELETE CASCADE, x REAL NOT NULL, y REAL NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE edges(source INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, target INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, PRIMARY KEY(source,target))',
          );
          await db.execute(
            'CREATE TABLE voice_drafts(memo_id INTEGER PRIMARY KEY REFERENCES memos(id) ON DELETE CASCADE, draft TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            "CREATE TABLE memo_branches(id INTEGER PRIMARY KEY, memo_id INTEGER NOT NULL REFERENCES memos(id) ON DELETE CASCADE, parent_id INTEGER REFERENCES memo_branches(id) ON DELETE CASCADE, text TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, x REAL, y REAL, shape TEXT NOT NULL DEFAULT 'rounded')",
          );
        },
        version: 1,
      ),
    );
  });
  tearDown(() async => store.db.close());

  test(
    'freezing initial positions never moves manually placed nodes',
    () async {
      final memo = await store.addMemo('tree');
      final a = await store.addBranch(memo, 'placed', x: 120, y: 300);
      final b = await store.addBranch(memo, 'legacy');
      await store.saveMissingBranchPositions(memo, {
        a: (999.0, 999.0),
        b: (400.0, 600.0),
      });
      final rows = await store.branches(memo);
      expect(rows.singleWhere((r) => r['id'] == a)['x'], 120.0);
      expect(rows.singleWhere((r) => r['id'] == b)['x'], 400.0);
      expect(rows.singleWhere((r) => r['id'] == b)['y'], 600.0);
    },
  );

  test(
    'voice commands only attach to a uniquely named memo and branch',
    () async {
      final note = await store.addMemo('게임 개발\n투자 및 작업 기록');
      final parent = await store.addBranch(note, 'NPC 시스템', x: 3000, y: 2700);
      final transcript = await store.addMemo(
        '게임 개발 트리 NPC 시스템 노드 아래 대화 개선 메모 추가',
      );
      expect(
        await store.applyMemoTreeCommand(
          '게임 개발',
          'NPC 시스템',
          '대화 개선',
          transcriptMemoId: transcript,
        ),
        isTrue,
      );
      var rows = await store.branches(note);
      expect(
        rows.singleWhere((row) => row['text'] == '대화 개선')['parent_id'],
        parent,
      );
      expect(await store.memoText(transcript), contains('대화 개선'));
      await store.addBranch(note, 'NPC 시스템');
      expect(
        await store.applyMemoTreeCommand(
          '게임 개발',
          'NPC 시스템',
          '중복',
          transcriptMemoId: transcript,
        ),
        isFalse,
      );
      rows = await store.branches(note);
      expect(rows.where((row) => row['text'] == '중복'), isEmpty);
      final second = await store.addMemo('게임 개발\n다른 기록');
      await store.addBranch(second, 'NPC 시스템');
      expect(
        await store.applyMemoTreeCommand(
          '게임 개발',
          'NPC 시스템',
          '중복',
          transcriptMemoId: transcript,
        ),
        isFalse,
      );
    },
  );

  test('version 4 backup retains old notes, graph and theme', () async {
    await store.restore(
      jsonEncode({
        'version': 4,
        'memos': [
          {
            'id': 1,
            'text': 'one',
            'updated': 1,
            'title': null,
            'color': 4294960081,
          },
          {
            'id': 2,
            'text': 'two',
            'updated': 2,
            'title': null,
            'color': 4294960081,
          },
        ],
        'nodes': [
          {'id': 1, 'memo_id': 1, 'x': 1.0, 'y': 2.0},
          {'id': 2, 'memo_id': 2, 'x': 3.0, 'y': 4.0},
        ],
        'edges': [
          {'source': 1, 'target': 2},
        ],
        'voice_drafts': [],
        'settings': [
          {'key': 'theme', 'value': 'sage'},
        ],
      }),
    );
    expect(await store.memoText(1), 'one');
    expect(await store.nodes(), hasLength(2));
    expect(await store.edges(), hasLength(1));
    expect(await store.themeName(), 'sage');
    expect(await store.branches(1), isEmpty);
  });

  test('opening a version 4 database upgrades without losing records', () async {
    final dir = await Directory.systemTemp.createTemp('gondut_migration_');
    final path = p.join(dir.path, 'memo_graph.db');
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE memos(id INTEGER PRIMARY KEY, text TEXT NOT NULL, updated INTEGER NOT NULL, title TEXT, color INTEGER NOT NULL DEFAULT 4294960081)',
          );
          await db.execute(
            'CREATE TABLE nodes(id INTEGER PRIMARY KEY, memo_id INTEGER NOT NULL REFERENCES memos(id) ON DELETE CASCADE, x REAL NOT NULL, y REAL NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE edges(source INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, target INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, PRIMARY KEY(source,target))',
          );
          await db.execute(
            'CREATE TABLE voice_drafts(memo_id INTEGER PRIMARY KEY REFERENCES memos(id) ON DELETE CASCADE, draft TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('memos', {'id': 7, 'text': 'kept', 'updated': 1});
          await db.insert('nodes', {'id': 4, 'memo_id': 7, 'x': 1.0, 'y': 2.0});
        },
      ),
    );
    await old.close();
    final upgraded = Store();
    try {
      await upgraded.open(path: path);
      expect(await upgraded.memoText(7), 'kept');
      expect(await upgraded.nodes(), hasLength(1));
      expect(await upgraded.memoRichText(7), isNull);
      await upgraded.addBranch(7, 'new tree');
      expect(await upgraded.branches(7), hasLength(1));
      await upgraded.db.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('rich text and nested branches survive backup and restore', () async {
    final id = await store.addMemo('');
    const rich =
        '[{"insert":"bold","attributes":{"bold":true}},{"insert":"\\n"}]';
    await store.saveRichMemo(id, 'bold', rich);
    const ink = '[[[0.1,0.2],[0.3,0.4]]]';
    await store.saveMemoInk(id, ink);
    final parent = await store.addBranch(id, 'idea');
    await store.setBranchShape(id, parent, 'diamond');
    final child = await store.addBranch(id, 'detail', parentId: parent);
    final backup = await store.backup();
    await store.restore(backup);
    expect(await store.memoRichText(id), rich);
    expect(await store.memoInk(id), ink);
    final branches = await store.branches(id);
    expect(branches, hasLength(2));
    expect(branches.singleWhere((e) => e['id'] == parent)['shape'], 'diamond');
    expect(branches.singleWhere((e) => e['id'] == child)['parent_id'], parent);
    await expectLater(store.moveBranch(id, parent, child), throwsStateError);
    expect(await store.branches(id), hasLength(2));
    await store.deleteBranch(id, parent);
    expect(await store.branches(id), isEmpty);
  });

  test(
    'free positions and connections survive backup and reject cycles',
    () async {
      final memo = await store.addMemo('example');
      final a = await store.addBranch(memo, 'a');
      final b = await store.addBranch(memo, 'b', parentId: a);
      await store.saveBranchPlacement(memo, b, a, {
        a: (100.0, 200.0),
        b: (450.0, 350.0),
      });
      final backup = await store.backup();
      await store.restore(backup);
      final rows = await store.branches(memo);
      final moved = rows.singleWhere((row) => row['id'] == b);
      expect(moved['x'], 450.0);
      expect(moved['y'], 350.0);
      expect(moved['parent_id'], a);
      await expectLater(
        store.saveBranchPlacement(memo, a, b, {a: (1.0, 2.0)}),
        throwsStateError,
      );
      expect(
        (await store.branches(memo)).singleWhere((row) => row['id'] == a)['x'],
        100.0,
      );
    },
  );

  test('language preference persists and survives backup', () async {
    expect(await store.languageName(), 'system');
    await store.setLanguageName('en');
    final backup = await store.backup();
    await store.setLanguageName('ko');
    await store.restore(backup);
    expect(await store.languageName(), 'en');
    for (final language in ['ja', 'zh', 'es']) {
      await store.setLanguageName(language);
      expect(await store.languageName(), language);
    }
    await store.setLanguageName('system');
    expect(await store.languageName(), 'system');
    await expectLater(store.setLanguageName('xx'), throwsArgumentError);
  });

  test(
    'reviewed process draft appends atomically and rejects changed sources',
    () async {
      final id = await store.addMemo('It rained. I stayed home.');
      final old = await store.addBranch(id, '내가 만든 가지');
      final items = [
        {'kind': '관찰', 'quote': 'It rained'},
        {'kind': '실행', 'quote': 'I stayed home'},
      ];
      expect(
        await store.appendReviewedProcessDraft(
          id,
          'It rained. I stayed home.',
          items,
        ),
        isTrue,
      );
      final branches = await store.branches(id);
      expect(branches, hasLength(5));
      expect(branches.singleWhere((e) => e['id'] == old)['text'], '내가 만든 가지');
      final observation = branches.singleWhere((e) => e['text'] == '관찰');
      expect(
        branches.singleWhere((e) => e['text'] == 'It rained')['parent_id'],
        observation['id'],
      );
      await store.saveMemo(id, 'Changed note');
      expect(
        await store.appendReviewedProcessDraft(
          id,
          'It rained. I stayed home.',
          items,
        ),
        isFalse,
      );
      expect(await store.branches(id), hasLength(5));
      await expectLater(
        store.appendReviewedProcessDraft(id, 'Changed note', [
          {'kind': '기타', 'quote': 'x'},
        ]),
        throwsFormatException,
      );
      expect(await store.branches(id), hasLength(5));
    },
  );
}
