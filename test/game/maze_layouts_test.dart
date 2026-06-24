import 'package:chompire/game/direction.dart';
import 'package:chompire/game/maze.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validates the per-level maze cycle (D-008 revised). Every layout must be
/// 28×31, left/right symmetric, fully connected (every pellet reachable from
/// the player start through tunnel wrap), and must keep the hard-coded ghost
/// AI / spawn coordinates (house, tunnel, fruit, start, no-up tiles) identical
/// across all layouts. Map 0 must also stay byte-for-byte the original so the
/// movement / targeting tests that assume its tiles keep passing.
void main() {
  // Levels 1..mapCount exercise each distinct layout exactly once; the cycle
  // then repeats (L = mapCount+1 returns to map 0).
  final levels = <int>[for (var l = 1; l <= Maze.mapCount; l++) l];

  /// Build the maze for a given level (1-based) at unit tile size.
  Maze mazeForLevel(int level) => Maze(tileSize: 8, level: level);

  // Walkable tile types (player + pellets); house/door are not walkable.
  bool walkable(TileType t) =>
      t == TileType.path || t == TileType.tunnel || t == TileType.gatePath;

  group('there are multiple cycling layouts', () {
    test('exactly 3 layouts cycle with the level', () {
      expect(Maze.mapCount, 3);
      // L1->0, L2->1, L3->2, L4->0 (cycle wraps).
      expect(mazeForLevel(1).level, 1);
      expect(mazeForLevel(4).level, 4);
    });

    test('the layouts are visibly distinct (different pellet counts/specs)', () {
      final specCounts =
          levels.map((l) => mazeForLevel(l).pelletSpecs.length).toList();
      // Not all identical — the outer pellet patterns differ between layouts.
      expect(specCounts.toSet().length, greaterThan(1));
    });

    test('cycling wraps: level mapCount+1 reuses map 0 geometry', () {
      final first = mazeForLevel(1);
      final wrapped = mazeForLevel(Maze.mapCount + 1);
      for (var row = 0; row < Maze.gridRows; row++) {
        for (var col = 0; col < Maze.gridCols; col++) {
          expect(wrapped.tileAt(col, row), first.tileAt(col, row));
        }
      }
    });
  });

  for (final level in levels) {
    group('layout for level $level', () {
      late Maze maze;
      setUp(() => maze = mazeForLevel(level));

      test('is 28x31 with 4 power pellets', () {
        expect(Maze.gridCols, 28);
        expect(Maze.gridRows, 31);
        expect(maze.pelletSpecs.where((s) => s.isPower).length, 4);
        expect(maze.pelletSpecs, isNotEmpty);
      });

      test('is left/right symmetric', () {
        for (var row = 0; row < Maze.gridRows; row++) {
          for (var col = 0; col < Maze.gridCols; col++) {
            expect(
              maze.tileAt(col, row),
              maze.tileAt(Maze.gridCols - 1 - col, row),
              reason: 'asymmetry at ($col,$row) on level $level',
            );
          }
        }
      });

      test('keeps the hard-coded ghost-AI / spawn coordinates', () {
        // House door + gate corridor.
        expect(maze.tileAt(13, 12), TileType.houseDoor);
        expect(maze.tileAt(14, 12), TileType.houseDoor);
        expect(walkable(maze.tileAt(13, 11)), isTrue); // gate row above door.
        expect(maze.tileAt(14, 14), TileType.house); // house interior.

        // Ghost starts: Blinky (14,11) walkable; Pinky/Inky/Clyde in the house.
        expect(walkable(maze.tileAt(14, 11)), isTrue);
        expect(maze.tileAt(14, 14), TileType.house);
        expect(maze.tileAt(12, 14), TileType.house);
        expect(maze.tileAt(16, 14), TileType.house);

        // Player start, fruit tile.
        expect(walkable(maze.tileAt(13, 23)), isTrue);
        expect(walkable(maze.tileAt(13, 17)), isTrue);

        // Tunnel row 14 wraps left<->right.
        expect(maze.isTunnelRow(14), isTrue);
        expect(
          maze.wrap(const TileCoord(0, 14).step(Direction.left)),
          const TileCoord(27, 14),
        );

        // No-up tiles (12..15 on rows 11 and 23) are walkable on every layout.
        for (var col = 12; col <= 15; col++) {
          for (final row in const [11, 23]) {
            expect(walkable(maze.tileAt(col, row)), isTrue,
                reason: 'no-up tile ($col,$row) must be walkable');
            expect(maze.isNoUpTile(TileCoord(col, row)), isTrue);
          }
        }
      });

      test('every pellet is reachable from the player start', () {
        const start = TileCoord(13, 23);
        final reached = <TileCoord>{start};
        final queue = <TileCoord>[start];
        while (queue.isNotEmpty) {
          final c = queue.removeLast();
          for (final dir in Direction.values) {
            final n = maze.wrap(c.step(dir));
            if (n.col < 0 ||
                n.col >= Maze.gridCols ||
                n.row < 0 ||
                n.row >= Maze.gridRows) {
              continue;
            }
            if (reached.contains(n)) continue;
            if (!walkable(maze.tileAt(n.col, n.row))) continue;
            reached.add(n);
            queue.add(n);
          }
        }
        for (final spec in maze.pelletSpecs) {
          expect(reached.contains(spec.tile), isTrue,
              reason: 'pellet at ${spec.tile} unreachable on level $level');
        }
      });
    });
  }
}
