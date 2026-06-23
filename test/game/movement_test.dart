import 'package:chompire/game/direction.dart';
import 'package:chompire/game/maze.dart';
import 'package:chompire/game/pacman.dart';
import 'package:chompire/game/pellets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 2/3 unit tests: grid movement (buffered turns, walls, tunnel wrap) and
/// pellet placement/eating. The maze model is pure Dart, so these run without a
/// game loop. We drive [Pacman.update] manually with fixed time steps.
void main() {
  late Maze maze;

  setUp(() {
    maze = Maze(tileSize: 8);
  });

  group('Maze map', () {
    test('parses to 28x31 and exposes pellet specs', () {
      expect(Maze.gridCols, 28);
      expect(Maze.gridRows, 31);
      // 282 standard + 4 power pellets (see _asciiMap).
      expect(maze.pelletSpecs.length, 286);
      expect(maze.pelletSpecs.where((s) => s.isPower).length, 4);
    });

    test('tunnel row wraps left<->right', () {
      // Stepping left off col 0 on the tunnel row lands on the far right.
      const left = TileCoord(0, 14);
      expect(maze.wrap(left.step(Direction.left)), const TileCoord(27, 14));
      expect(maze.isTunnelRow(14), isTrue);
      expect(maze.isTunnelRow(1), isFalse);
    });

    test('player cannot enter the ghost house', () {
      // Tile just above the house door region is path; the door itself blocks.
      expect(maze.tileAt(13, 12), TileType.houseDoor);
      // From (13,11) moving down hits the door -> blocked.
      expect(maze.canEnter(const TileCoord(13, 11), Direction.down), isFalse);
    });
  });

  group('PelletField', () {
    test('loads pellets from the maze and eats them', () {
      final field = PelletField(maze: maze)..loadFromMaze();
      expect(field.remaining, 286);

      final spec = maze.pelletSpecs.first;
      final eaten = field.eatAt(spec.tile);
      expect(eaten, isNotNull);
      expect(field.remaining, 285);
      // Eating the same tile again returns null.
      expect(field.eatAt(spec.tile), isNull);
    });
  });

  group('Pacman movement', () {
    Pacman spawn(TileCoord start) {
      final p = Pacman(maze: maze, startTile: start);
      // onLoad sets size from maze.tileSize; movement doesn't need it but the
      // continuous position fields are initialized from the start tile already.
      return p;
    }

    void advance(Pacman p, double seconds, {double step = 1 / 60}) {
      var t = 0.0;
      while (t < seconds) {
        p.update(step);
        t += step;
      }
    }

    test('moves along an open corridor', () {
      // Row 5 is a fully open corridor (#..........................#).
      final p = spawn(const TileCoord(13, 5));
      expect(p.currentDir, Direction.left);
      advance(p, 0.5); // 6 t/s * 0.5s = 3 tiles.
      expect(p.tile.row, 5);
      expect(p.tile.col, lessThan(13));
    });

    test('stops at a wall', () {
      // Move left toward the left wall on row 5 and keep going.
      final p = spawn(const TileCoord(13, 5));
      advance(p, 5.0); // far more than enough to reach the wall.
      // Col 1 is the leftmost path on row 5 (col 0 is wall).
      expect(p.tile.col, 1);
    });

    test('buffered turn is applied at the next legal tile center', () {
      // Start at (6,5) heading left. Col 6 row 6 is open path, so DOWN is a
      // legal turn that should be taken at the (6,5) center.
      final p = spawn(const TileCoord(6, 5));
      p.queueDirection(Direction.down);
      advance(p, 0.5);
      expect(p.currentDir, Direction.down);
      expect(p.tile.row, greaterThan(5));
    });

    test('instant reverse flips direction immediately', () {
      final p = spawn(const TileCoord(13, 5));
      expect(p.currentDir, Direction.left);
      p.queueDirection(Direction.right);
      expect(p.currentDir, Direction.right);
    });

    test('wraps through the tunnel', () {
      // Spawn at the left end of the tunnel row heading left.
      final p = spawn(const TileCoord(0, 14));
      // Already facing left; advance enough to step off the edge.
      advance(p, 0.3);
      // Should have wrapped to the right side.
      expect(p.tile.col, greaterThan(20));
    });
  });
}
