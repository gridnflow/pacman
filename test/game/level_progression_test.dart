import 'package:chompire/game/direction.dart';
import 'package:chompire/game/level_tuning.dart';
import 'package:chompire/game/maze.dart';
import 'package:chompire/game/pacman.dart';
import 'package:chompire/game/pacman_game.dart';
import 'package:chompire/game/scoring.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-7 unit tests: level progression + per-level tuning (§8) and high-score
/// persistence wiring (§7). Pure logic is exercised directly; the level-clear
/// flow is driven through a booted [PacmanGame].
void main() {
  group('LevelTuning (§8)', () {
    test('frightened seconds shrink with level and reach 0 at L9', () {
      expect(LevelTuning.forLevel(1).frightenedSeconds, 6);
      expect(LevelTuning.forLevel(2).frightenedSeconds, 5);
      expect(LevelTuning.forLevel(5).frightenedSeconds, 2);
      expect(LevelTuning.forLevel(7).frightenedSeconds, 1);
      expect(LevelTuning.forLevel(9).frightenedSeconds, 0);
      expect(LevelTuning.forLevel(20).frightenedSeconds, 0);
    });

    test('L9+ has no frightened window', () {
      expect(LevelTuning.forLevel(8).hasFrightened, isTrue);
      expect(LevelTuning.forLevel(9).hasFrightened, isFalse);
    });

    test('speeds ramp up across the L1 / L2-4 / L5+ bands', () {
      final l1 = LevelTuning.forLevel(1);
      final l3 = LevelTuning.forLevel(3);
      final l5 = LevelTuning.forLevel(5);
      expect(l1.playerSpeedMultiplier, lessThan(l3.playerSpeedMultiplier));
      expect(l3.playerSpeedMultiplier, lessThan(l5.playerSpeedMultiplier));
      expect(l1.ghostSpeedMultiplier, lessThan(l5.ghostSpeedMultiplier));
    });

    test('level is clamped to >= 1', () {
      expect(LevelTuning.forLevel(0).level, 1);
      expect(LevelTuning.forLevel(-3).frightenedSeconds, 6);
    });
  });

  group('GameState high-score persistence callback (§7)', () {
    test('onHighScoreChanged fires only when the high score increases', () {
      final saved = <int>[];
      final s = GameState(onHighScoreChanged: saved.add)..reset();
      s.addPellet(); // 10 -> new high score.
      s.addPellet(); // 20 -> new high score.
      expect(saved, [10, 20]);
    });

    test('loadHighScore does not trigger the persist callback', () {
      final saved = <int>[];
      final s = GameState(onHighScoreChanged: saved.add);
      s.loadHighScore(5000);
      expect(saved, isEmpty);
      expect(s.highScore, 5000);
    });

    test('score below the loaded high score does not re-persist', () {
      final saved = <int>[];
      final s = GameState(onHighScoreChanged: saved.add)
        ..loadHighScore(1000)
        ..reset();
      s.addPellet(); // score 10, below 1000 -> no callback.
      expect(saved, isEmpty);
      expect(s.highScore, 1000);
    });
  });

  group('level-clear flow (§7 / §8)', () {
    testWidgets('clearing all pellets advances the level and retunes actors',
        (tester) async {
      final state = GameState()..reset();
      final game = PacmanGame(state: state);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(state.level, 1);
      expect(game.pacman.speedMultiplier,
          LevelTuning.forLevel(1).playerSpeedMultiplier);

      // Eat every pellet, then step once to trigger the level-clear branch.
      final field = game.pellets;
      for (final spec in game.maze.pelletSpecs) {
        field.eatAt(spec.tile);
      }
      expect(field.remaining, 0);
      game.update(1 / 60);

      expect(state.level, 2);
      expect(field.remaining, greaterThan(0)); // refilled.
      expect(game.pacman.speedMultiplier,
          LevelTuning.forLevel(2).playerSpeedMultiplier);
      expect(game.pacman.speedMultiplier,
          greaterThan(LevelTuning.forLevel(1).playerSpeedMultiplier));
    });
  });

  group('game-over freezes the loop (§7)', () {
    testWidgets('update is a no-op once lives reach 0', (tester) async {
      final state = GameState()..reset();
      final game = PacmanGame(state: state);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      while (!state.isGameOver) {
        state.loseLife();
      }
      final tile = game.pacman.tile;
      game.update(1 / 60);
      expect(game.pacman.tile, tile); // player did not move.
    });
  });

  test('Pacman effective speed scales with the level multiplier', () {
    final maze = Maze(tileSize: 8);
    final p = Pacman(maze: maze, startTile: const TileCoord(13, 23));
    p.speedMultiplier = 0.5;
    expect(p.effectiveSpeed, Pacman.speedTilesPerSec * 0.5);
  });
}
