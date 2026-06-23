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

/// Maze model + renderer.
///
/// Phase 1 (Skeleton): loads grid dimensions and renders an *empty* maze — a
/// procedural border so the playfield is visible on device. The canonical
/// 28×31 tilemap (requirements §1.4) and the maze-atlas sprite path are TODOs
/// for Phase 2.
class Maze extends PositionComponent {
  Maze({required this.tileSize});

  /// Logical pixels per tile in the maze model (requirements §1.1: 8).
  static const int gridCols = 28;
  static const int gridRows = 31;
  static const int tileSizeLogical = 8;

  /// Render-space size of a tile (logical * camera scale handled by caller).
  final double tileSize;

  /// Row-major grid of tile types. `_grid[row][col]`.
  late final List<List<TileType>> _grid = _buildPlaceholderGrid();

  // --- Palette (style-guide §2) ---
  static const Color _bg = Color(0xFF0B0B1A);
  static const Color _wallFill = Color(0xFF1B2A6B);
  static const Color _wallEdge = Color(0xFF3B6BFF);

  final Paint _bgPaint = Paint()..color = _bg;
  final Paint _wallFillPaint = Paint()..color = _wallFill;
  final Paint _wallEdgePaint = Paint()
    ..color = _wallEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  @override
  void onLoad() {
    size = Vector2(gridCols * tileSize, gridRows * tileSize);
  }

  /// TODO(Phase 2): replace with a load of the canonical ASCII/int tilemap
  /// checked into assets/tiles/. For the skeleton we generate an enclosing
  /// border of walls with an open interior so an "empty maze" renders.
  List<List<TileType>> _buildPlaceholderGrid() {
    return List.generate(gridRows, (row) {
      return List.generate(gridCols, (col) {
        final isBorder =
            row == 0 || row == gridRows - 1 || col == 0 || col == gridCols - 1;
        return isBorder ? TileType.wall : TileType.path;
      });
    });
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

  /// Whether [dir] from tile [c] leads into a tile an *actor* may enter.
  /// TODO(Phase 2): differentiate player vs ghost (house/door access) and
  /// honor tunnel wrap.
  bool canEnter(TileCoord c, Direction dir) {
    final next = c.step(dir);
    final t = tileAtCoord(next);
    return t != TileType.wall && t != TileType.house && t != TileType.houseDoor;
  }

  @override
  void render(Canvas canvas) {
    // Background.
    canvas.drawRect(size.toRect(), _bgPaint);

    // Draw wall tiles. TODO(Phase 2): draw from maze_atlas.png or procedural
    // rounded-rect strokes per style-guide §7.1; this is the placeholder path.
    for (var row = 0; row < gridRows; row++) {
      for (var col = 0; col < gridCols; col++) {
        if (_grid[row][col] != TileType.wall) continue;
        final rect = Rect.fromLTWH(
          col * tileSize,
          row * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawRect(rect, _wallFillPaint);
        canvas.drawRect(rect.deflate(0.5), _wallEdgePaint);
      }
    }
  }
}
