import 'package:flutter_test/flutter_test.dart';
import 'package:memo_graph/voice.dart';

void main() {
  test('free speech needs an explicit destination prefix', () {
    expect(parseDraftDestination('게임 트리의 NPC 노드 아래: 대화를 개선하기로 했다.'),
        (tree: '게임', parent: 'NPC'));
    expect(
        parseDraftDestination(
            'In the Game tree under the NPC node: I chose dialogue.'),
        (tree: 'Game', parent: 'NPC'));
    expect(parseDraftDestination('게임 트리의 NPC 이야기를 했다.'), isNull);
    expect(parseDraftDestination('게임 트리의 NPC 노드 아래:'), isNull);
  });
  test('explicit command must name tree, node and content', () {
    final command = parseCommand('게임 트리 NPC 노드 아래 대화 개선 메모 추가');
    expect(command?.tree, '게임');
    expect(command?.parent, 'NPC');
    expect(command?.content, '대화 개선');
    expect(parseCommand('게임에 추가해'), isNull);
    final natural = parseCommand('게임 개발 트리의 NPC 시스템 아래에 대화 패턴 개선 메모를 추가해.');
    expect(natural?.tree, '게임 개발');
    expect(natural?.parent, 'NPC 시스템');
    expect(natural?.content, '대화 패턴 개선');
  });
  test('draft quotes occur verbatim and unrelated text creates no category',
      () {
    const source = '오늘 손해 봤다. 다음에는 확인해야겠다.';
    final draft = extractDraft(source);
    expect(draft, isNotEmpty);
    for (final item in draft) {
      expect(source.contains(item['quote']!), isTrue);
    }
    expect(extractDraft('점심으로 국수를 먹었다.'), isEmpty);
  });
  test('explicit multilingual commands preserve the named values', () {
    for (final sample in [
      (
        'Add note improve dialogue under NPC node in Game tree.',
        'Game',
        'improve dialogue'
      ),
      ('ゲームツリーのNPCノードの下に会話改善メモを追加して', 'ゲーム', '会話改善'),
      (
        'Agrega la nota mejorar diálogo debajo del nodo NPC del árbol Juego.',
        'Juego',
        'mejorar diálogo'
      ),
      (
        "Ajoute la note améliorer dialogue sous le nœud NPC de l’arbre Jeu.",
        'Jeu',
        'améliorer dialogue'
      ),
      (
        'Adicionar a nota melhorar diálogo abaixo do nó NPC da árvore Jogo.',
        'Jogo',
        'melhorar diálogo'
      ),
      ('在游戏树的NPC节点下添加对话改善笔记。', '游戏', '对话改善'),
    ]) {
      final command = parseCommand(sample.$1);
      expect(command, isNotNull, reason: sample.$1);
      expect(command!.parent, 'NPC');
      expect(command.tree, sample.$2);
      expect(command.content, sample.$3);
    }
    expect(parseCommand('Add a note about the game.'), isNull);
    expect(parseCommand('NPCの下に追加'), isNull);
  });
}
