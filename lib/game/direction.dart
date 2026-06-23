/// Shared coordinate / direction primitives for the maze simulation.
///
/// Tile coordinates are integer `(col, row)`: `col` increases rightward (x),
/// `row` increases downward (y). `(0,0)` is the top-left tile. See
/// `docs/requirements.md` §0.
///
/// NOTE (60fps): these are tiny value types. Hot paths in the game loop should
/// avoid allocating new [TileCoord]s every frame where it can be helped; prefer
/// reusing integer fields on actors and only constructing coords for targeting
/// math (which is O(1) per ghost per tile).
library;

/// One of the four cardinal directions. No diagonals.
enum Direction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Direction(this.dx, this.dy);

  /// Unit vector x component (col delta).
  final int dx;

  /// Unit vector y component (row delta).
  final int dy;

  /// The 180° opposite of this direction.
  Direction get opposite => switch (this) {
        Direction.up => Direction.down,
        Direction.down => Direction.up,
        Direction.left => Direction.right,
        Direction.right => Direction.left,
      };
}

/// An immutable integer tile coordinate.
class TileCoord {
  const TileCoord(this.col, this.row);

  final int col;
  final int row;

  TileCoord operator +(TileCoord other) =>
      TileCoord(col + other.col, row + other.row);

  TileCoord operator -(TileCoord other) =>
      TileCoord(col - other.col, row - other.row);

  TileCoord operator *(int scalar) => TileCoord(col * scalar, row * scalar);

  /// Move [steps] tiles in [dir].
  TileCoord step(Direction dir, [int steps = 1]) =>
      TileCoord(col + dir.dx * steps, row + dir.dy * steps);

  /// Squared Euclidean distance to [other]. Used for ghost targeting; squared
  /// is sufficient for comparisons and avoids floating point (requirements §0).
  int dist2(TileCoord other) {
    final dc = col - other.col;
    final dr = row - other.row;
    return dc * dc + dr * dr;
  }

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'TileCoord($col, $row)';
}
