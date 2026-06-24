import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';

/// The kinds of tile in the maze grid. Each tile is exactly one type.
/// See `docs/requirements.md` §1.1.
enum TileType {
  wall,
  path,
  tunnel,
  house,
  houseDoor,
  gatePath,
}

/// A pellet placement parsed from the maze map. Consumed by `PelletField`.
class PelletSpec {
  const PelletSpec(this.tile, this.isPower);

  final TileCoord tile;
  final bool isPower;
}

/// Maze model + renderer.
///
/// Phase 2: parses a hand-authored 28×31 ASCII tilemap (see [_asciiMap]) into a
/// tile grid and a pellet layout. The map is left/right symmetric, fully
/// connected, has a left↔right tunnel row, and a central ghost house. The
/// maze-atlas sprite path remains a later-phase TODO; walls are drawn
/// procedurally for now.
class Maze extends PositionComponent {
  Maze({required this.tileSize});

  /// Logical pixels per tile in the maze model (requirements §1.1: 8).
  static const int gridCols = 28;
  static const int gridRows = 31;
  static const int tileSizeLogical = 8;

  /// Hand-authored maze. Exactly [gridRows] rows of [gridCols] chars.
  ///
  /// Legend:
  ///   '#' wall            '.' pellet path     'o' power pellet
  ///   ' ' empty path      'T' tunnel path     '-' house door
  ///   'H' house interior  'G' gate path (open path in front of the door)
  ///
  /// Left/right symmetric, fully connected, four power pellets near the corners,
  /// and a tunnel row (row 14) that wraps left↔right.
  static const List<String> _asciiMap = <String>[
    '############################', // 0
    '#............##............#', // 1
    '#.####.#####.##.#####.####.#', // 2
    '#o####.#####.##.#####.####o#', // 3
    '#.####.#####.##.#####.####.#', // 4
    '#..........................#', // 5
    '#.####.##.########.##.####.#', // 6
    '#.####.##.########.##.####.#', // 7
    '#......##....##....##......#', // 8
    '######.#####.##.#####.######', // 9
    '######.#####.##.#####.######', // 10
    '######.##..........##.######', // 11
    '######.##.###--###.##.######', // 12
    '######.##.#HHHHHH#.##.######', // 13
    'TTTTTT....#HHHHHH#....TTTTTT', // 14
    '######.##.#HHHHHH#.##.######', // 15
    '######.##.########.##.######', // 16
    '######.##..........##.######', // 17
    '######.##.########.##.######', // 18
    '######.##.########.##.######', // 19
    '#............##............#', // 20
    '#.####.#####.##.#####.####.#', // 21
    '#.####.#####.##.#####.####.#', // 22
    '#o..##.......GG.......##..o#', // 23
    '###.##.##.########.##.##.###', // 24
    '###.##.##.########.##.##.###', // 25
    '#......##....##....##......#', // 26
    '#.##########.##.##########.#', // 27
    '#.##########.##.##########.#', // 28
    '#..........................#', // 29
    '############################', // 30
  ];

  /// Render-space size of a tile (logical * camera scale handled by caller).
  final double tileSize;

  /// Row-major grid of tile types. `_grid[row][col]`.
  late final List<List<TileType>> _grid = _buildGridFromAscii();

  /// Pellet placements parsed from the map. Each entry is `(coord, isPower)`.
  /// [PelletField.loadFromMaze] consumes this so the map is the single source
  /// of truth for pellet layout.
  late final List<PelletSpec> pelletSpecs = _buildPelletSpecs();

  // --- Palette (style-guide §2) ---
  static const Color _bg = Color(0xFF0B0B1A);
  static const Color _wallEdge = Color(0xFF3B6BFF); // neon blue stroke
  static const Color _gate = Color(0xFFFFB3D9); // ghost-house gate (pink)

  final Paint _bgPaint = Paint()..color = _bg;

  /// Neon wall stroke. Width scales with the tile so it reads at any zoom.
  late final Paint _wallEdgePaint = Paint()
    ..color = _wallEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = (tileSize / Maze.tileSizeLogical) * 1.0
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  late final Paint _gatePaint = Paint()
    ..color = _gate
    ..strokeWidth = (tileSize / Maze.tileSizeLogical) * 1.5
    ..strokeCap = StrokeCap.round;

  @override
  void onLoad() {
    size = Vector2(gridCols * tileSize, gridRows * tileSize);
  }

  /// Parse [_asciiMap] into the tile grid. Pellet/power markers map to passable
  /// path; only structural tile *types* live here (pellet contents are tracked
  /// separately via [pelletSpecs]).
  List<List<TileType>> _buildGridFromAscii() {
    assert(_asciiMap.length == gridRows, 'map must have $gridRows rows');
    return List.generate(gridRows, (row) {
      final line = _asciiMap[row];
      assert(line.length == gridCols, 'row $row must be $gridCols cols');
      return List.generate(gridCols, (col) {
        return _typeForChar(line.codeUnitAt(col));
      });
    });
  }

  static TileType _typeForChar(int code) {
    switch (code) {
      case 0x23: // '#'
        return TileType.wall;
      case 0x54: // 'T'
        return TileType.tunnel;
      case 0x48: // 'H'
        return TileType.house;
      case 0x2D: // '-'
        return TileType.houseDoor;
      case 0x47: // 'G'
        return TileType.gatePath;
      default: // '.', 'o', ' '
        return TileType.path;
    }
  }

  List<PelletSpec> _buildPelletSpecs() {
    final specs = <PelletSpec>[];
    for (var row = 0; row < gridRows; row++) {
      final line = _asciiMap[row];
      for (var col = 0; col < gridCols; col++) {
        final ch = line.codeUnitAt(col);
        if (ch == 0x2E) {
          specs.add(PelletSpec(TileCoord(col, row), false)); // '.'
        } else if (ch == 0x6F) {
          specs.add(PelletSpec(TileCoord(col, row), true)); // 'o'
        }
      }
    }
    return specs;
  }

  /// The tile type at a grid coordinate, or [TileType.wall] if out of bounds
  /// (out-of-bounds reads as impassable except via tunnel wrap, handled later).
  TileType tileAt(int col, int row) {
    if (row < 0 || row >= gridRows || col < 0 || col >= gridCols) {
      return TileType.wall;
    }
    return _grid[row][col];
  }

  TileType tileAtCoord(TileCoord c) => tileAt(c.col, c.row);

  /// Tiles where ghosts in scatter/chase may not select UP (requirements §4.6).
  /// The classic positions: the tiles just above the ghost-house exit, and the
  /// matching pair lower in the maze. Door is at row 12 (cols 13–14); the tile
  /// above it on the gate corridor is row 11. The lower no-up pair sits on
  /// row 23 (the GATE_PATH 'G' tiles' row neighbors), per the canonical layout.
  /// (col,row) pairs as a flat list — TileCoord overrides ==, so it can't live
  /// in a const Set; we test by value instead.
  static const List<(int, int)> _noUpTiles = <(int, int)>[
    // Above the house exit (row 11).
    (12, 11), (13, 11), (14, 11), (15, 11),
    // Lower no-up zone (row 23, around the central junction).
    (12, 23), (13, 23), (14, 23), (15, 23),
  ];

  /// Whether a scatter/chase ghost is forbidden from turning UP on [c] (§4.6).
  bool isNoUpTile(TileCoord c) {
    for (final (col, row) in _noUpTiles) {
      if (c.col == col && c.row == row) return true;
    }
    return false;
  }

  /// Tunnel rows wrap horizontally. Returns the wrapped tile if [c] just stepped
  /// off either edge on a tunnel row, otherwise [c] unchanged.
  TileCoord wrap(TileCoord c) {
    if (c.col < 0) return TileCoord(gridCols - 1, c.row);
    if (c.col >= gridCols) return TileCoord(0, c.row);
    return c;
  }

  /// Whether [c] is on a tunnel row (left↔right wrap is allowed here).
  bool isTunnelRow(int row) {
    if (row < 0 || row >= gridRows) return false;
    return _grid[row][0] == TileType.tunnel ||
        _grid[row][gridCols - 1] == TileType.tunnel;
  }

  /// Whether [dir] from tile [c] leads into a tile the *player* may enter.
  /// Honors tunnel wrap; the ghost house + door are impassable to the player.
  bool canEnter(TileCoord c, Direction dir) {
    final next = wrap(c.step(dir));
    final t = tileAtCoord(next);
    return t != TileType.wall && t != TileType.house && t != TileType.houseDoor;
  }

  /// Whether [dir] from tile [c] leads into a tile a *ghost* may occupy while
  /// roaming the maze. Ghosts treat the house interior and door as impassable
  /// once they are out (house entry/exit is scripted separately by the ghost),
  /// but unlike the player they may stand on GATE_PATH. Honors tunnel wrap.
  bool ghostCanEnter(TileCoord c, Direction dir) {
    final next = wrap(c.step(dir));
    final t = tileAtCoord(next);
    return t != TileType.wall &&
        t != TileType.house &&
        t != TileType.houseDoor;
  }

  /// Whether the tile at [col],[row] is a wall (out-of-bounds counts as wall so
  /// the maze border closes cleanly). Used by the autotiler to decide which
  /// edges of a wall tile face open space.
  bool _isWallAt(int col, int row) => tileAt(col, row) == TileType.wall;

  @override
  void render(Canvas canvas) {
    // Background.
    canvas.drawRect(size.toRect(), _bgPaint);

    // Autotiled neon walls (style-guide §7.1): instead of filling each wall
    // tile, draw a neon-blue stroke only on the edges that face open (non-wall)
    // space. Adjacent walls share clean continuous lines and corners round off,
    // giving the classic single-line maze look. Inset by ~1.5px (logical) so
    // parallel corridor walls read as two lines, not one fat block.
    final unit = tileSize / Maze.tileSizeLogical; // logical px -> render px
    final inset = unit * 1.5;

    for (var row = 0; row < gridRows; row++) {
      for (var col = 0; col < gridCols; col++) {
        if (_grid[row][col] != TileType.wall) continue;

        final left = col * tileSize;
        final top = row * tileSize;
        final right = left + tileSize;
        final bottom = top + tileSize;

        // Inset edges of this tile's neon outline.
        final il = left + inset;
        final it = top + inset;
        final ir = right - inset;
        final ib = bottom - inset;

        final openUp = !_isWallAt(col, row - 1);
        final openDown = !_isWallAt(col, row + 1);
        final openLeft = !_isWallAt(col - 1, row);
        final openRight = !_isWallAt(col + 1, row);

        // Straight neon segments on each side that faces open space.
        if (openUp) {
          canvas.drawLine(Offset(il, it), Offset(ir, it), _wallEdgePaint);
        }
        if (openDown) {
          canvas.drawLine(Offset(il, ib), Offset(ir, ib), _wallEdgePaint);
        }
        if (openLeft) {
          canvas.drawLine(Offset(il, it), Offset(il, ib), _wallEdgePaint);
        }
        if (openRight) {
          canvas.drawLine(Offset(ir, it), Offset(ir, ib), _wallEdgePaint);
        }
      }
    }

    // Ghost-house gate: a horizontal pink bar across the door tiles.
    for (var row = 0; row < gridRows; row++) {
      for (var col = 0; col < gridCols; col++) {
        if (_grid[row][col] != TileType.houseDoor) continue;
        final cy = row * tileSize + tileSize * 0.5;
        canvas.drawLine(
          Offset(col * tileSize, cy),
          Offset((col + 1) * tileSize, cy),
          _gatePaint,
        );
      }
    }
  }
}
