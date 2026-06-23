import 'package:chompire/game/direction.dart';
import 'package:chompire/game/ghost.dart';
import 'package:chompire/game/ghosts/blinky.dart';
import 'package:chompire/game/maze.dart';
import 'package:chompire/game/pacman_game.dart';
import 'package:chompire/game/scoring.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-5 unit tests for the power-pellet / frightened / eaten flow
/// (requirements §5.3–§5.6, §6.2). Ghost-level behavior is exercised through
/// the public API and the [Ghost.chooseDirectionForTest] seam; the end-to-end
/// power-pellet flow is driven through a booted [PacmanGame].
void main() {
  final maze = Maze(tileSize: 8);

  Blinky ghost() => Blinky(maze: maze, startTile: const TileCoord(0, 0));

  TargetContext ctx(TileCoord t) =>
      TargetContext(playerTile: t, playerDir: Direction.left, blinkyTile: t);

  group('eaten targeting (§5.6)', () {
    test('eaten ghost targets the house door tile', () {
      final g = ghost();
      g.setMode(GhostMode.eaten);
      expect(g.targetTile(ctx(const TileCoord(1, 1))), Ghost.houseDoorTile);
    });
  });

  group('frightened wander is deterministic (§5.5)', () {
    test('same seed + same intersections => same choice', () {
      // Two ghosts share the default fixed seed, so a frightened decision from
      // the same tile/facing must agree (reproducible PRNG).
      final a = ghost();
      final b = ghost();
      const j = TileCoord(6, 5); // 4-way junction.
      final da = a.chooseDirectionForTest(
        tile: j,
        facing: Direction.right,
        mode: GhostMode.frightened,
        ctx: ctx(const TileCoord(0, 0)),
      );
      final db = b.chooseDirectionForTest(
        tile: j,
        facing: Direction.right,
        mode: GhostMode.frightened,
        ctx: ctx(const TileCoord(0, 0)),
      );
      expect(da, db);
    });

    test('frightened never picks the 180° reversal', () {
      final g = ghost();
      for (var i = 0; i < 20; i++) {
        final dir = g.chooseDirectionForTest(
          tile: const TileCoord(6, 5),
          facing: Direction.right, // reverse = left.
          mode: GhostMode.frightened,
          ctx: ctx(const TileCoord(0, 0)),
        );
        expect(dir, isNot(Direction.left));
      }
    });
  });

  group('frightened speed (§8)', () {
    test('frightened slower than normal, eaten fastest', () {
      final g = ghost();
      g.setMode(GhostMode.chase);
      final normal = g.speedTilesPerSec;
      g.setMode(GhostMode.frightened);
      final frightened = g.speedTilesPerSec;
      g.setMode(GhostMode.eaten);
      final eaten = g.speedTilesPerSec;
      expect(frightened, lessThan(normal));
      expect(eaten, greaterThan(normal));
    });
  });

  group('power-pellet end-to-end flow (§5.3 / §6.2)', () {
    // Advance a real game for [seconds] in fixed steps.
    void advance(PacmanGame game, double seconds, {double step = 1 / 60}) {
      var t = 0.0;
      while (t < seconds) {
        game.update(step);
        t += step;
      }
    }

    testWidgets('power pellet frightens outside ghosts + reverses them',
        (tester) async {
      final state = GameState()..reset();
      final game = PacmanGame(state: state);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Blinky starts outside; a ghost still inside the house must NOT frighten.
      final blinky = game.ghosts.first;
      expect(blinky.isOutsideHouse, isTrue);
      final inside = game.ghosts.firstWhere((g) => !g.isOutsideHouse);

      // Teleport the player onto the top-left power pellet at (1,3) and step.
      final before = state.score;
      game.pacman.resetTo(const TileCoord(1, 3));
      game.update(1 / 60);

      expect(state.score - before, GameState.powerPelletPoints);
      expect(blinky.mode, GhostMode.frightened);
      expect(inside.mode, isNot(GhostMode.frightened));
    });

    testWidgets('colliding with a frightened ghost eats it (chain + eaten)',
        (tester) async {
      final state = GameState()..reset();
      final game = PacmanGame(state: state);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final blinky = game.ghosts.first;
      game.pacman.resetTo(const TileCoord(1, 3));
      game.update(1 / 60);
      expect(blinky.mode, GhostMode.frightened);

      // Blinky sits on (13,11) right after frightening. Place the player one
      // tile to its right heading left so it commits onto Blinky's tile this
      // frame (the grid-step model advances _tile at the center it leaves).
      expect(blinky.tile, const TileCoord(13, 11));
      final before = state.score;
      final lives = state.lives;
      game.pacman.resetTo(const TileCoord(14, 11));
      game.onDirectionInput(Direction.left);
      game.update(1 / 60);

      expect(blinky.mode, GhostMode.eaten); // became "eyes".
      expect(state.lives, lives); // not a life loss.
      // 200 for the ghost (+ maybe a 10-pt dot on the tile we walked onto).
      final gained = state.score - before;
      expect(gained == 200 || gained == 210, isTrue, reason: 'gained=$gained');
    });

    testWidgets('frightened window expires -> ghosts return to global mode',
        (tester) async {
      final state = GameState()..reset();
      final game = PacmanGame(state: state);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final blinky = game.ghosts.first;
      game.pacman.resetTo(const TileCoord(1, 3));
      game.update(1 / 60);
      expect(blinky.mode, GhostMode.frightened);

      // Run past the 6s frightened window. Keep the player parked off-pellet.
      game.pacman.resetTo(const TileCoord(13, 23));
      advance(game, 7.0);
      expect(blinky.mode, isNot(GhostMode.frightened));
      expect(blinky.mode, anyOf(GhostMode.scatter, GhostMode.chase));
    });
  });

  group('scoring chain (§6.2)', () {
    test('eatGhost yields 200/400/800/1600 after startGhostChain', () {
      final s = GameState()..reset();
      s.startGhostChain();
      expect(s.eatGhost(), 200);
      expect(s.eatGhost(), 400);
      expect(s.eatGhost(), 800);
      expect(s.eatGhost(), 1600);
      // A fresh window resets the chain.
      s.startGhostChain();
      expect(s.eatGhost(), 200);
    });
  });
}
