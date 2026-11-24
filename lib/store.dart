import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'process_labels.dart' show processDraftLabels;

class Store {
  late Database db;
  Future<void> open({String? path}) async {
    db = await openDatabase(
      path ?? join(await getDatabasesPath(), 'memo_graph.db'),
      version: 12,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        await d.execute(
          'CREATE TABLE memos(id INTEGER PRIMARY KEY, text TEXT NOT NULL, updated INTEGER NOT NULL, title TEXT, color INTEGER NOT NULL DEFAULT 4294960081)',
        );
        await d.execute(
          'CREATE TABLE nodes(id INTEGER PRIMARY KEY, memo_id INTEGER NOT NULL REFERENCES memos(id) ON DELETE CASCADE, x REAL NOT NULL, y REAL NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE edges(source INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, target INTEGER NOT NULL REFERENCES nodes(id) ON DELETE CASCADE, PRIMARY KEY(source,target), CHECK(source != target))',
        );
        await d.execute(
          'CREATE TABLE voice_drafts(memo_id INTEGER PRIMARY KEY REFERENCES memos(id) ON DELETE CASCADE, draft TEXT NOT NULL)',
        );
        await d.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await d.execute('ALTER TABLE memos ADD COLUMN rich_text TEXT');
        await d.execute('ALTER TABLE memos ADD COLUMN ink TEXT');
        await d.execute('ALTER TABLE memos ADD COLUMN graph_ink TEXT');
        await d.execute(
          'ALTER TABLE memos ADD COLUMN title_manual INTEGER NOT NULL DEFAULT 0',
        );
        await _createBranches(d);
        await _addOrganization(d);
      },
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2)
          await d.execute(
            'CREATE TABLE voice_drafts(memo_id INTEGER PRIMARY KEY REFERENCES memos(id) ON DELETE CASCADE, draft TEXT NOT NULL)',
          );
        if (oldVersion < 3) {
          await d.execute('ALTER TABLE memos ADD COLUMN title TEXT');
        }
        if (oldVersion < 4) {
          await d.execute(
            'ALTER TABLE memos ADD COLUMN color INTEGER NOT NULL DEFAULT 4294960081',
          );
          await d.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
        }
        if (oldVersion < 5) {
          await d.execute('ALTER TABLE memos ADD COLUMN rich_text TEXT');
          await _createBranches(d);
        }
        if (oldVersion < 6) {
          await d.execute('ALTER TABLE memos ADD COLUMN ink TEXT');
        }
        if (oldVersion >= 5 && oldVersion < 7) {
          await d.execute('ALTER TABLE memo_branches ADD COLUMN x REAL');
          await d.execute('ALTER TABLE memo_branches ADD COLUMN y REAL');
        }
        if (oldVersion >= 5 && oldVersion < 8) {
          await d.execute(
            "ALTER TABLE memo_branches ADD COLUMN shape TEXT NOT NULL DEFAULT 'rounded'",
          );
        }
        if (oldVersion < 9) {
          await d.execute(
            'ALTER TABLE memos ADD COLUMN title_manual INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 10) await _addOrganization(d);
        if (oldVersion < 11)
          await d.execute('ALTER TABLE memos ADD COLUMN graph_ink TEXT');
        if (oldVersion < 12) {
          await d.insert('settings', {
            'key': 'tutorial_complete',
            'value': 'yes',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      },
    );
  }

  static Future<void> _createBranches(DatabaseExecutor db) => db.execute(
    "CREATE TABLE memo_branches(id INTEGER PRIMARY KEY, memo_id INTEGER NOT NULL REFERENCES memos(id) ON DELETE CASCADE, parent_id INTEGER REFERENCES memo_branches(id) ON DELETE CASCADE, text TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, x REAL, y REAL, shape TEXT NOT NULL DEFAULT 'rounded')",
  );

  static Future<void> _addOrganization(DatabaseExecutor db) async {
    await db.execute(
      'CREATE TABLE folders(id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
    );
    await db.execute(
      'ALTER TABLE memos ADD COLUMN folder_id INTEGER REFERENCES folders(id) ON DELETE SET NULL',
    );
    await db.execute(
      "ALTER TABLE memos ADD COLUMN kind TEXT NOT NULL DEFAULT 'note'",
    );
    await db.execute(
      "ALTER TABLE memo_branches ADD COLUMN title TEXT NOT NULL DEFAULT ''",
    );
    await db.execute('ALTER TABLE memo_branches ADD COLUMN rich_text TEXT');
    await db.execute('ALTER TABLE memo_branches ADD COLUMN ink TEXT');
  }

  Future<List<Map<String, Object?>>> folders() =>
      db.query('folders', orderBy: 'name COLLATE NOCASE, id');
  Future<int> addFolder(String name) =>
      db.insert('folders', {'name': name.trim()});
  Future<void> moveMemoToFolder(int id, int? folderId) async {
    await db.update(
      'memos',
      {'folder_id': folderId},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFolder(int id) async =>
      db.delete('folders', where: 'id=?', whereArgs: [id]);
  Future<void> setMemoKind(int id, String kind) async {
    if (kind != 'note' && kind != 'graph') throw ArgumentError.value(kind);
    await db.update('memos', {'kind': kind}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> setBranchTitle(int memoId, int branchId, String title) async {
    await db.update(
      'memo_branches',
      {'title': title.trim()},
      where: 'memo_id=? AND id=?',
      whereArgs: [memoId, branchId],
    );
  }

  Future<void> saveBranchContent(
    int memoId,
    int branchId,
    String title,
    String text,
    String richText, {
    String? ink,
  }) async {
    await db.update(
      'memo_branches',
      {'title': title.trim(), 'text': text, 'rich_text': richText, 'ink': ink},
      where: 'memo_id=? AND id=?',
      whereArgs: [memoId, branchId],
    );
  }

  Future<void> setBranchShape(int memoId, int id, String shape) async {
    if (!const {'rounded', 'pill', 'circle', 'diamond'}.contains(shape))
      throw ArgumentError('Invalid node shape');
    await db.update(
      'memo_branches',
      {'shape': shape},
      where: 'id=? AND memo_id=?',
      whereArgs: [id, memoId],
    );
  }

  Future<void> saveBranchPlacement(
    int memoId,
    int branchId,
    int? parentId,
    Map<int, (double, double)> placements,
  ) => db.transaction((tx) async {
    final rows = await tx.query(
      'memo_branches',
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    final byId = {for (final row in rows) row['id'] as int: row};
    if (!byId.containsKey(branchId) ||
        (parentId != null && !byId.containsKey(parentId)))
      throw StateError('가지가 없습니다.');
    var current = parentId;
    final seen = <int>{};
    while (current != null) {
      if (current == branchId || !seen.add(current))
        throw StateError('하위 가지에 연결할 수 없습니다.');
      current = byId[current]?['parent_id'] as int?;
    }
    for (final entry in placements.entries) {
      if (!byId.containsKey(entry.key) ||
          !entry.value.$1.isFinite ||
          !entry.value.$2.isFinite)
        throw StateError('잘못된 위치입니다.');
      await tx.update(
        'memo_branches',
        {
          'x': entry.value.$1,
          'y': entry.value.$2,
          if (entry.key == branchId) 'parent_id': parentId,
        },
        where: 'id=? AND memo_id=?',
        whereArgs: [entry.key, memoId],
      );
    }
    if (!placements.containsKey(branchId)) throw StateError('이동할 위치가 없습니다.');
  });

  Future<void> saveMissingBranchPositions(
    int memoId,
    Map<int, (double, double)> positions,
  ) => db.transaction((tx) async {
    for (final entry in positions.entries) {
      await tx.update(
        'memo_branches',
        {'x': entry.value.$1, 'y': entry.value.$2},
        where: 'memo_id=? AND id=? AND (x IS NULL OR y IS NULL)',
        whereArgs: [memoId, entry.key],
      );
    }
  });

  Future<String?> memoRichText(int id) async {
    final rows = await db.query(
      'memos',
      columns: ['rich_text'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['rich_text'] as String?;
  }

  Future<String?> memoInk(int id) async {
    final rows = await db.query(
      'memos',
      columns: ['ink'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['ink'] as String?;
  }

  Future<String?> graphInk(int id) async {
    final rows = await db.query(
      'memos',
      columns: ['graph_ink'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['graph_ink'] as String?;
  }

  Future<void> saveGraphInk(int id, String ink) async {
    await db.update(
      'memos',
      {'graph_ink': ink, 'updated': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> saveMemoInk(int id, String ink) async {
    await db.update(
      'memos',
      {'ink': ink, 'updated': DateTime.now().millisecondsSinceEpoch},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> saveRichMemo(int id, String text, String richText) async {
    await db.rawUpdate(
      'UPDATE memos SET text=?, rich_text=?, updated=?, title=CASE WHEN title_manual=1 OR (title IS NOT NULL AND instr(?, title)>0) THEN title ELSE NULL END WHERE id=?',
      [text, richText, DateTime.now().millisecondsSinceEpoch, text, id],
    );
  }

  Future<List<Map<String, Object?>>> branches(int memoId) => db.query(
    'memo_branches',
    where: 'memo_id=?',
    whereArgs: [memoId],
    orderBy: 'position, id',
  );

  Future<int> addBranch(
    int memoId,
    String text, {
    int? parentId,
    double? x,
    double? y,
  }) => db.transaction((tx) async {
    if (parentId != null) {
      final parent = await tx.query(
        'memo_branches',
        columns: ['id'],
        where: 'id=? AND memo_id=?',
        whereArgs: [parentId, memoId],
      );
      if (parent.isEmpty) throw StateError('상위 가지를 찾을 수 없습니다.');
    }
    return tx.insert('memo_branches', {
      'memo_id': memoId,
      'parent_id': parentId,
      'text': text,
      if (x != null && y != null) 'x': x,
      if (x != null && y != null) 'y': y,
      'position': DateTime.now().millisecondsSinceEpoch,
    });
  });

  Future<void> renameBranch(int memoId, int branchId, String text) async {
    await db.update(
      'memo_branches',
      {'text': text},
      where: 'id=? AND memo_id=?',
      whereArgs: [branchId, memoId],
    );
  }

  Future<void> moveBranch(int memoId, int branchId, int? parentId) =>
      db.transaction((tx) async {
        final all = await tx.query(
          'memo_branches',
          where: 'memo_id=?',
          whereArgs: [memoId],
        );
        final ids = all.map((e) => e['id'] as int).toSet();
        if (!ids.contains(branchId) ||
            (parentId != null && !ids.contains(parentId)))
          throw StateError('가지를 찾을 수 없습니다.');
        var current = parentId;
        final visited = <int>{};
        while (current != null) {
          if (current == branchId || !visited.add(current))
            throw StateError('가지의 하위 항목으로 옮길 수 없습니다.');
          final row = all.firstWhere((e) => e['id'] == current);
          current = row['parent_id'] as int?;
        }
        await tx.update(
          'memo_branches',
          {
            'parent_id': parentId,
            'position': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'id=? AND memo_id=?',
          whereArgs: [branchId, memoId],
        );
      });

  Future<void> deleteBranch(int memoId, int branchId) async {
    await db.delete(
      'memo_branches',
      where: 'id=? AND memo_id=?',
      whereArgs: [branchId, memoId],
    );
  }

  Future<List<Map<String, Object?>>> memos([String query = '']) => db.rawQuery(
    'SELECT m.*, (SELECT COUNT(*) FROM nodes n WHERE n.memo_id=m.id) AS node_count FROM memos m WHERE m.text LIKE ? OR m.title LIKE ? ORDER BY m.updated DESC',
    ['%$query%', '%$query%'],
  );
  Future<List<Map<String, Object?>>> nodes() => db.rawQuery(
    'SELECT n.*, m.text, m.color FROM nodes n JOIN memos m ON m.id=n.memo_id ORDER BY n.id',
  );
  Future<List<Map<String, Object?>>> edges() => db.query('edges');
  Future<String?> memoText(int id) async {
    final rows = await db.query(
      'memos',
      columns: ['text'],
      where: 'id=?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['text'] as String;
  }

  Future<int> addMemo(String text) => db.insert('memos', {
    'text': text,
    'updated': DateTime.now().millisecondsSinceEpoch,
  });
  Future<void> saveMemo(int id, String text) async {
    await db.rawUpdate(
      'UPDATE memos SET text=?, updated=?, title=CASE WHEN title_manual=1 OR (title IS NOT NULL AND instr(?, title)>0) THEN title ELSE NULL END WHERE id=?',
      [text, DateTime.now().millisecondsSinceEpoch, text, id],
    );
  }

  Future<void> renameMemo(int id, String title) async {
    final value = title.trim();
    final count = await db.update(
      'memos',
      {
        'title': value.isEmpty ? null : value,
        'title_manual': value.isEmpty ? 0 : 1,
        'updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id=?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Memo not found');
  }

  Future<void> saveGeneratedTitle(int id, String source, String? title) async {
    if (title == null || title.isEmpty || !source.contains(title)) return;
    await db.update(
      'memos',
      {'title': title},
      where:
          'id=? AND text=? AND title_manual=0 AND (title IS NULL OR title=?)',
      whereArgs: [id, source, ''],
    );
  }

  Future<void> deleteMemo(int id) async {
    await db.delete('memos', where: 'id=?', whereArgs: [id]);
  }

  Future<String> themeName() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: ['theme'],
    );
    return rows.isEmpty ? 'lavender' : rows.single['value'] as String;
  }

  Future<bool> charactersEnabled() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: ['characters'],
    );
    return rows.isEmpty || rows.single['value'] != 'off';
  }

  Future<bool> tutorialComplete() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: ['tutorial_complete'],
    );
    return rows.isNotEmpty && rows.single['value'] == 'yes';
  }

  Future<void> setTutorialComplete() async {
    await db.insert('settings', {
      'key': 'tutorial_complete',
      'value': 'yes',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setCharactersEnabled(bool enabled) async {
    await db.insert('settings', {
      'key': 'characters',
      'value': enabled ? 'on' : 'off',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String> languageName() async {
    final rows = await db.query(
      'settings',
      where: 'key=?',
      whereArgs: ['language'],
    );
    final value = rows.isEmpty ? 'system' : rows.single['value'] as String;
    return const {'system', 'ko', 'en', 'ja', 'zh', 'es'}.contains(value)
        ? value
        : 'system';
  }

  Future<void> setLanguageName(String name) async {
    if (!const {'system', 'ko', 'en', 'ja', 'zh', 'es'}.contains(name))
      throw ArgumentError.value(name);
    await db.insert('settings', {
      'key': 'language',
      'value': name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setThemeName(String name) async {
    await db.insert('settings', {
      'key': 'theme',
      'value': name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addNode(int memo, double x, double y) async {
    await db.insert('nodes', {'memo_id': memo, 'x': x, 'y': y});
  }

  Future<void> moveNode(int id, double x, double y) async {
    await db.update('nodes', {'x': x, 'y': y}, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteNode(int id) async {
    await db.delete('nodes', where: 'id=?', whereArgs: [id]);
  }

  Future<void> connect(int a, int b) async {
    if (a != b) {
      await db.insert('edges', {
        'source': a,
        'target': b,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> disconnect(int a, int b) async {
    await db.delete('edges', where: 'source=? AND target=?', whereArgs: [a, b]);
  }

  Future<String> backup() => db.transaction(
    (tx) async => jsonEncode({
      'version': 11,
      'folders': await tx.query('folders', orderBy: 'id'),
      'memos': await tx.query('memos'),
      'nodes': await tx.query('nodes'),
      'edges': await tx.query('edges'),
      'voice_drafts': await tx.query('voice_drafts'),
      'settings': await tx.query('settings'),
      'memo_branches': await tx.query('memo_branches', orderBy: 'id'),
    }),
  );
  Future<void> saveDraft(int memoId, List<Map<String, String>> draft) async {
    await db.insert('voice_drafts', {
      'memo_id': memoId,
      'draft': jsonEncode(draft),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> putDraftIntoMemoTree(
    int memoId,
    List<Map<String, String>> draft, {
    Map<String, String>? categoryNames,
  }) => db.transaction((tx) async {
    final memo = await tx.query(
      'memos',
      columns: ['id'],
      where: 'id=?',
      whereArgs: [memoId],
    );
    if (memo.isEmpty) throw StateError('메모를 찾을 수 없습니다.');
    for (var i = 0; i < draft.length; i++) {
      await tx.insert('memo_branches', {
        'memo_id': memoId,
        'parent_id': null,
        'text':
            '${categoryNames?[draft[i]['kind']] ?? draft[i]['kind']}: ${draft[i]['quote']}',
        'position': DateTime.now().millisecondsSinceEpoch + i,
      });
    }
    await tx.delete('voice_drafts', where: 'memo_id=?', whereArgs: [memoId]);
  });

  /// Append a reviewed draft atomically, without changing any existing branch.
  /// A changed or deleted source memo rejects the whole operation.
  Future<bool> appendReviewedProcessDraft(
    int memoId,
    String source,
    List<Map<String, String>> items, {
    Map<String, String>? categoryNames,
  }) => db.transaction((tx) async {
    final rows = await tx.query(
      'memos',
      columns: ['text'],
      where: 'id=?',
      whereArgs: [memoId],
    );
    if (rows.length != 1 || rows.single['text'] != source) return false;
    if (items.isEmpty || items.length > 12)
      throw const FormatException('초안 항목을 확인해 주세요.');
    for (final item in items) {
      final quote = item['quote']?.trim() ?? '';
      if (!processDraftLabels.contains(item['kind']) ||
          quote.isEmpty ||
          quote.length > 200) {
        throw const FormatException('초안 항목을 확인해 주세요.');
      }
    }
    final order = DateTime.now().millisecondsSinceEpoch;
    // Causal drafts carry stable, backwards-only IDs. Deleted causes leave
    // their effects unconnected instead of attaching them to the wrong node.
    if (items.any((item) => item.containsKey('id'))) {
      final inserted = <String, int>{};
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final id = item['id'];
        if (id == null || inserted.containsKey(id)) {
          throw const FormatException('Invalid draft relationship');
        }
        final branch = await tx.insert('memo_branches', {
          'memo_id': memoId,
          'parent_id': inserted[item['parent']],
          'text': item['quote']!.trim(),
          'position': order + i,
        });
        inserted[id] = branch;
      }
      return true;
    }
    for (var i = 0; i < processDraftLabels.length; i++) {
      final kind = processDraftLabels[i];
      final matching = items.where((item) => item['kind'] == kind).toList();
      if (matching.isEmpty) continue;
      final group = await tx.insert('memo_branches', {
        'memo_id': memoId,
        'parent_id': null,
        'text': categoryNames?[kind] ?? kind,
        'position': order + i,
      });
      for (var j = 0; j < matching.length; j++) {
        await tx.insert('memo_branches', {
          'memo_id': memoId,
          'parent_id': group,
          'text': matching[j]['quote']!.trim(),
          'position': order + j,
        });
      }
    }
    return true;
  });

  Future<bool> saveAnalysisDraft(
    int memoId,
    String source,
    List<Map<String, String>> draft,
  ) => db.transaction((tx) async {
    final rows = await tx.query(
      'memos',
      columns: ['text'],
      where: 'id=?',
      whereArgs: [memoId],
    );
    if (rows.isEmpty || rows.single['text'] != source) return false;
    final existing = await tx.query(
      'voice_drafts',
      columns: ['memo_id'],
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    if (existing.isNotEmpty) return false;
    await tx.insert('voice_drafts', {
      'memo_id': memoId,
      'draft': jsonEncode(draft),
    });
    return true;
  });

  /// Only act when the named memo and branch are both unambiguous.
  Future<bool> applyMemoTreeCommand(
    String tree,
    String parent,
    String content, {
    int? transcriptMemoId,
  }) => db.transaction((tx) async {
    final name = tree.trim();
    final parentName = parent.trim();
    final text = content.trim();
    if (name.isEmpty || parentName.isEmpty || text.isEmpty || text.length > 200)
      return false;
    final memos = await tx.query('memos', columns: ['id', 'title', 'text']);
    final matchingMemos = memos.where((memo) {
      if (memo['id'] == transcriptMemoId) return false;
      final title = (memo['title'] as String?)?.trim();
      final firstLine = (memo['text'] as String).split('\n').first.trim();
      return title == name || firstLine == name;
    }).toList();
    if (matchingMemos.length != 1) return false;
    final memoId = matchingMemos.single['id'] as int;
    final branches = await tx.query(
      'memo_branches',
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    final matches = branches
        .where((row) => (row['text'] as String).trim() == parentName)
        .toList();
    if (matches.length != 1) return false;
    await tx.insert('memo_branches', {
      'memo_id': memoId,
      'parent_id': matches.single['id'],
      'text': text,
      'position': DateTime.now().millisecondsSinceEpoch,
    });
    return true;
  });

  Future<bool> applyExplicitCommand(
    String tree,
    String parent,
    String content,
  ) => db.transaction((tx) async {
    final allNodes = await tx.rawQuery(
      'SELECT n.id, n.x, n.y, m.text FROM nodes n JOIN memos m ON m.id=n.memo_id',
    );
    final allEdges = await tx.query('edges');
    final incoming = allEdges.map((e) => e['target'] as int).toSet();
    final roots = allNodes
        .where(
          (n) =>
              !incoming.contains(n['id']) &&
              (n['text'] as String).trim() == tree,
        )
        .toList();
    if (roots.length != 1 || content.isEmpty) return false;
    final visited = <int>{};
    final queue = <int>[roots.single['id'] as int];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) continue;
      for (final edge in allEdges) {
        if (edge['source'] == current) queue.add(edge['target'] as int);
      }
    }
    final parents = allNodes
        .where(
          (n) =>
              visited.contains(n['id']) &&
              (n['text'] as String).trim() == parent,
        )
        .toList();
    if (parents.length != 1) return false;
    final target = parents.single;
    final memo = await tx.insert('memos', {
      'text': content,
      'updated': DateTime.now().millisecondsSinceEpoch,
    });
    final child = await tx.insert('nodes', {
      'memo_id': memo,
      'x': (target['x'] as num).toDouble() + 200,
      'y': (target['y'] as num).toDouble() + 100,
    });
    await tx.insert('edges', {'source': target['id'], 'target': child});
    return true;
  });
  Future<List<Map<String, String>>> getDraft(int memoId) async {
    final rows = await db.query(
      'voice_drafts',
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    if (rows.isEmpty) return [];
    return (jsonDecode(rows.first['draft'] as String) as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  /// Attach only a saved draft whose original text and unique destination still
  /// match. All checks and writes run in the same transaction.
  Future<bool> attachDraftToExplicitDestination(
    int memoId,
    String source,
    String tree,
    String parent,
    List<Map<String, String>> expectedDraft,
  ) => db.transaction((tx) async {
    final memo = await tx.query(
      'memos',
      columns: ['text'],
      where: 'id=?',
      whereArgs: [memoId],
    );
    final drafts = await tx.query(
      'voice_drafts',
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    if (memo.isEmpty ||
        memo.single['text'] != source ||
        drafts.length != 1 ||
        drafts.single['draft'] != jsonEncode(expectedDraft))
      return false;
    final existingNodes = await tx.query(
      'nodes',
      columns: ['id'],
      where: 'memo_id=?',
      whereArgs: [memoId],
    );
    if (existingNodes.isNotEmpty) return false;
    final allNodes = await tx.rawQuery(
      'SELECT n.id, n.x, n.y, m.text FROM nodes n JOIN memos m ON m.id=n.memo_id',
    );
    final allEdges = await tx.query('edges');
    final incoming = allEdges.map((e) => e['target'] as int).toSet();
    final roots = allNodes
        .where(
          (n) =>
              !incoming.contains(n['id']) &&
              (n['text'] as String).trim() == tree,
        )
        .toList();
    if (roots.length != 1) return false;
    final visited = <int>{};
    final queue = <int>[roots.single['id'] as int];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) continue;
      for (final edge in allEdges) {
        if (edge['source'] == current) queue.add(edge['target'] as int);
      }
    }
    final parents = allNodes
        .where(
          (n) =>
              visited.contains(n['id']) &&
              (n['text'] as String).trim() == parent,
        )
        .toList();
    if (parents.length != 1) return false;
    final draft = (jsonDecode(drafts.single['draft'] as String) as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
    if (draft.isEmpty) return false;
    final target = parents.single;
    final rootX = (target['x'] as num).toDouble() + 200;
    final rootY = (target['y'] as num).toDouble() + 100;
    final root = await tx.insert('nodes', {
      'memo_id': memoId,
      'x': rootX,
      'y': rootY,
    });
    await tx.insert('edges', {'source': target['id'], 'target': root});
    for (var i = 0; i < draft.length; i++) {
      final item = draft[i];
      final id = await tx.insert('memos', {
        'text': '${item['kind']}: ${item['quote']}',
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
      final child = await tx.insert('nodes', {
        'memo_id': id,
        'x': rootX + 220.0,
        'y': rootY + i * 110.0,
      });
      await tx.insert('edges', {'source': root, 'target': child});
    }
    await tx.delete('voice_drafts', where: 'memo_id=?', whereArgs: [memoId]);
    return true;
  });

  Future<void> placeDraft(int memoId, {int? parentNodeId}) async {
    final draft = await getDraft(memoId);
    if (draft.isEmpty) throw StateError('배치할 초안이 없습니다.');
    await db.transaction((tx) async {
      Map<String, Object?>? parent;
      if (parentNodeId != null) {
        final rows = await tx.query(
          'nodes',
          where: 'id=?',
          whereArgs: [parentNodeId],
        );
        if (rows.length != 1) throw StateError('선택한 노드가 없습니다.');
        parent = rows.single;
      }
      final rootX = parent == null
          ? 80.0
          : (parent['x'] as num).toDouble() + 200;
      final rootY = parent == null
          ? 80.0
          : (parent['y'] as num).toDouble() + 100;
      final root = await tx.insert('nodes', {
        'memo_id': memoId,
        'x': rootX,
        'y': rootY,
      });
      if (parentNodeId != null) {
        await tx.insert('edges', {'source': parentNodeId, 'target': root});
      }
      for (var i = 0; i < draft.length; i++) {
        final item = draft[i];
        final id = await tx.insert('memos', {
          'text': '${item['kind']}: ${item['quote']}',
          'updated': DateTime.now().millisecondsSinceEpoch,
        });
        final child = await tx.insert('nodes', {
          'memo_id': id,
          'x': rootX + 220.0,
          'y': rootY + i * 110.0,
        });
        await tx.insert('edges', {'source': root, 'target': child});
      }
      await tx.delete('voice_drafts', where: 'memo_id=?', whereArgs: [memoId]);
    });
  }

  Future<void> restore(String data) async {
    final decoded = jsonDecode(data);
    if (decoded is! Map ||
        (decoded['version'] != 1 &&
            decoded['version'] != 2 &&
            decoded['version'] != 3 &&
            decoded['version'] != 4 &&
            decoded['version'] != 5 &&
            decoded['version'] != 6 &&
            decoded['version'] != 7 &&
            decoded['version'] != 8 &&
            decoded['version'] != 9 &&
            decoded['version'] != 10 &&
            decoded['version'] != 11) ||
        decoded['memos'] is! List ||
        decoded['nodes'] is! List ||
        decoded['edges'] is! List) {
      throw const FormatException('지원하지 않는 백업 형식');
    }
    await db.transaction((tx) async {
      await tx.delete('voice_drafts');
      await tx.delete('memo_branches');
      await tx.delete('edges');
      await tx.delete('nodes');
      await tx.delete('memos');
      await tx.delete('folders');
      if (decoded['version'] >= 10) {
        if (decoded['folders'] is! List)
          throw const FormatException('Invalid folders');
        for (final row in decoded['folders']) {
          if (row is! Map) throw const FormatException('Invalid folder');
          await tx.insert('folders', Map<String, Object?>.from(row));
        }
      }
      for (final table in ['memos', 'nodes', 'edges']) {
        for (final row in decoded[table]) {
          if (row is! Map) throw const FormatException('잘못된 백업 항목');
          await tx.insert(table, Map<String, Object?>.from(row));
        }
      }
      if (decoded['version'] >= 2) {
        if (decoded['voice_drafts'] is! List)
          throw const FormatException('초안 형식 오류');
        for (final row in decoded['voice_drafts']) {
          if (row is! Map) throw const FormatException('초안 형식 오류');
          await tx.insert('voice_drafts', Map<String, Object?>.from(row));
        }
      }
      if (decoded['version'] >= 4) {
        if (decoded['settings'] is! List)
          throw const FormatException('설정 형식 오류');
        await tx.delete('settings');
        for (final row in decoded['settings']) {
          if (row is! Map) throw const FormatException('설정 형식 오류');
          await tx.insert('settings', Map<String, Object?>.from(row));
        }
      }
      if (decoded['version'] >= 5) {
        if (decoded['memo_branches'] is! List)
          throw const FormatException('가지 형식 오류');
        for (final row in decoded['memo_branches']) {
          if (row is! Map) throw const FormatException('가지 형식 오류');
          await tx.insert('memo_branches', Map<String, Object?>.from(row));
        }
        final crossed = await tx.rawQuery(
          'SELECT c.id FROM memo_branches c JOIN memo_branches p ON c.parent_id=p.id WHERE c.memo_id != p.memo_id',
        );
        if (crossed.isNotEmpty)
          throw const FormatException('다른 메모의 가지를 연결할 수 없습니다');
      }
      final invalid = await tx.rawQuery('PRAGMA foreign_key_check');
      if (invalid.isNotEmpty) throw const FormatException('백업의 연결이 올바르지 않습니다');
    });
  }
}
