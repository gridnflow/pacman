import 'package:chompire/game/direction.dart';
import 'package:chompire/game/ghost.dart';
import 'package:chompire/game/ghosts/blinky.dart';
import 'package:chompire/game/ghosts/clyde.dart';
import 'package:chompire/game/ghosts/inky.dart';
import 'package:chompire/game/ghosts/pinky.dart';
import 'package:chompire/game/maze.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sample Phase-1 test covering the highest-value correctness risk: ghost chase
/// targeting (requirements §4.8). The targeting math is pure, so we can test it
/// without a running game loop. Movement / FSM tests arrive in Phase 4.
void main() {
  final maze = Maze(tileSize: 8);

  TargetContext ctx({
    required TileCoord player,
    required Direction dir,
    TileCoord blinky = const TileCoord(0, 0),
  }) =>
      TargetContext(playerTile: player, playerDir: dir, blinkyTile: blinky);

  group('Blinky (direct chase)', () {
    test('targets the player tile', () {
      final blinky = Blinky(maze: maze, startTile: const TileCoord(0, 0));
      expect(
        blinky.chaseTarget(ctx(player: const TileCoord(10, 12), dir: Direction.left)),
        const TileCoord(10, 12),
      );
    });
  });

  group('Pinky (ambush, 4 ahead)', () {
    test('targets 4 tiles ahead when facing left', () {
      final pinky = Pinky(maze: maze, startTile: const TileCoord(0, 0));
      expect(
        pinky.chaseTarget(ctx(player: const TileCoord(10, 12), dir: Direction.left)),
        const TileCoord(6, 12),
      );
    });

    test('reproduces the UP overflow bug (4 up AND 4 left)', () {
      final pinky = Pinky(maze: maze, startTile: const TileCoord(0, 0));
      expect(
        pinky.chaseTarget(ctx(player: const TileCoord(10, 12), dir: Direction.up)),
        const TileCoord(6, 8),
      );
    });
  });

  group('Inky (Blinky-derived flank)', () {
    test('doubles the Blinky→pivot vector', () {
      // player faces right, pivot = (12,12); blinky = (8,12).
      // target = 2*pivot - blinky = (24,24) - (8,12) = (16,12).
      final inky = Inky(maze: maze, startTile: const TileCoord(0, 0));
      expect(
        inky.chaseTarget(ctx(
          player: const TileCoord(10, 12),
          dir: Direction.right,
          blinky: const TileCoord(8, 12),
        )),
        const TileCoord(16, 12),
      );
    });
  });

  group('Clyde (shy, 8-tile boundary)', () {
    test('chases the player when 8+ tiles away (d² >= 64)', () {
      final clyde = Clyde(maze: maze, startTile: const TileCoord(0, 0));
      // player at (8,0): d² = 64 -> chase.
      expect(
        clyde.chaseTarget(ctx(player: const TileCoord(8, 0), dir: Direction.left)),
        const TileCoord(8, 0),
      );
    });

    test('flees to its corner when closer than 8 tiles (d² < 64)', () {
      final clyde = Clyde(maze: maze, startTile: const TileCoord(0, 0));
      // player at (7,0): d² = 49 -> flee to scatter corner (0,31).
      expect(
        clyde.chaseTarget(ctx(player: const TileCoord(7, 0), dir: Direction.left)),
        clyde.scatterCorner,
      );
    });
  });
}
