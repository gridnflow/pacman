import 'package:chompire/game/direction.dart';
import 'package:chompire/game/ghost.dart';
import 'package:chompire/game/ghosts/blinky.dart';
import 'package:chompire/game/maze.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase-4 unit tests for the deterministic ghost turn decision (requirements
/// §4.0 / §4.6): min dist² exit selection, UP>LEFT>DOWN>RIGHT tie-break, no 180°
/// reversal at will, and the no-up-tile constraint. We use Blinky because its
/// chase target is exactly the player's tile, so the target is trivially
/// controllable. Decisions run via the [Ghost.chooseDirectionForTest] seam.
void main() {
  final maze = Maze(tileSize: 8);

  Blinky ghost() => Blinky(maze: maze, startTile: const TileCoord(0, 0));

  TargetContext targetAt(TileCoord t) =>
      TargetContext(playerTile: t, playerDir: Direction.left, blinkyTile: t);

  group('turn decision at the (6,5) 4-way junction', () {
    // Sanity: (6,5) has open path in all four directions.
    test('junction is open on all sides', () {
      const j = TileCoord(6, 5);
      expect(maze.canEnter(j, Direction.up), isTrue);
      expect(maze.canEnter(j, Direction.down), isTrue);
      expect(maze.canEnter(j, Direction.left), isTrue);
      expect(maze.canEnter(j, Direction.right), isTrue);
    });

    test('excludes the 180° reversal', () {
      // Moving right into the junction; target is straight back (left). The
      // reverse (left) must be excluded, so it cannot be chosen even though it
      // minimizes distance.
      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: const TileCoord(6, 5),
        facing: Direction.right,
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(0, 5)), // far left -> wants to go left.
      );
      expect(dir, isNot(Direction.left));
    });

    test('tie-break prefers UP when distances are equal', () {
      // Target on the junction tile itself: up/down/right are all dist²=1
      // (left excluded as the reverse). UP wins the tie-break.
      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: const TileCoord(6, 5),
        facing: Direction.right, // reverse = left, excluded.
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(6, 5)),
      );
      expect(dir, Direction.up);
    });

    test('tie-break prefers LEFT over DOWN/RIGHT when UP excluded by reverse',
        () {
      // Moving down -> reverse = up is excluded. Remaining left/down/right are
      // all equidistant to the junction tile; LEFT wins.
      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: const TileCoord(6, 5),
        facing: Direction.down,
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(6, 5)),
      );
      expect(dir, Direction.left);
    });

    test('picks the exit that minimizes dist² to the target', () {
      // Target far to the right -> RIGHT is strictly closest.
      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: const TileCoord(6, 5),
        facing: Direction.down, // reverse = up excluded; right still open.
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(20, 5)),
      );
      expect(dir, Direction.right);
    });
  });

  group('forced reversal', () {
    test('a queued reverse flips direction regardless of target', () {
      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: const TileCoord(6, 5),
        facing: Direction.right,
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(20, 5)), // would otherwise go right.
        queueReverse: true,
      );
      expect(dir, Direction.left); // opposite of right.
    });
  });

  group('no-up constraint (§4.6)', () {
    test('(12,11) is a no-up tile', () {
      expect(maze.isNoUpTile(const TileCoord(12, 11)), isTrue);
      expect(maze.isNoUpTile(const TileCoord(6, 5)), isFalse);
    });

    test('a scatter/chase ghost may not turn UP on a no-up tile', () {
      // Target straight up; geometrically UP would minimize distance, but the
      // no-up gate must exclude it. Facing right so the reverse (left) is also
      // excluded; remaining legal exits are UP (gated) and RIGHT.
      const noUp = TileCoord(12, 11);
      expect(maze.canEnter(noUp, Direction.up), isTrue);

      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: noUp,
        facing: Direction.right,
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(12, 0)), // straight up.
      );
      expect(dir, isNot(Direction.up));
      expect(dir, Direction.right); // the only other open, non-reverse exit.
    });

    test(
        'control: on a non-no-up tile the engine DOES pick UP toward the target',
        () {
      // Same geometry one row up at the open junction column, but this tile is
      // not a no-up tile, so UP (the distance-minimizing exit) is chosen. This
      // proves the exclusion above is the no-up gate, not the geometry.
      const open = TileCoord(6, 5);
      expect(maze.isNoUpTile(open), isFalse);

      final g = ghost();
      final dir = g.chooseDirectionForTest(
        tile: open,
        facing: Direction.right, // reverse = left excluded.
        mode: GhostMode.chase,
        ctx: targetAt(const TileCoord(6, 0)), // straight up.
      );
      expect(dir, Direction.up);
    });
  });
}
