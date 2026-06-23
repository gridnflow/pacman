import 'package:chompire/game/pacman_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-1 smoke test: the game boots, builds its world (maze + actors), and the
/// empty maze renders without throwing. Confirms the skeleton is wired together.
void main() {
  testWidgets('PacmanGame boots and renders the empty maze', (tester) async {
    final game = PacmanGame();
    await tester.pumpWidget(
      MaterialApp(home: GameWidget(game: game)),
    );
    // Let onLoad() complete and a frame render.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.maze, isNotNull);
    expect(game.ghosts.length, 4);
    expect(tester.takeException(), isNull);
  });
}
