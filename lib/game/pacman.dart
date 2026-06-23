import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'maze.dart';

/// The player ("Muncher"). Grid-locked, continuous-speed movement with
/// *buffered* input (requirements §3, control-scheme §2).
///
/// Phase 1 (Skeleton): renders a placeholder gold disc at a start tile. Movement,
/// buffered turns, and the chomp animation are Phase 2 TODOs.
class Pacman extends PositionComponent {
  Pacman({required this.maze, required TileCoord startTile})
      : _tile = startTile,
        super(anchor: Anchor.center);

  final Maze maze;

  /// Current tile (floor of pixel / TILE_SIZE). Mutated by movement in Phase 2.
  // ignore: prefer_final_fields
  TileCoord _tile;

  /// Direction the player is currently moving. Mutated by movement in Phase 2.
  // ignore: prefer_final_fields
  Direction _currentDir = Direction.left;

  /// Most recent buffered input. Applied at the next legal tile center
  /// (requirements §3.1). `null` = no pending turn.
  // ignore: unused_field
  Direction? _desiredDir;

  TileCoord get tile => _tile;
  Direction get currentDir => _currentDir;

  // Style-guide §2: muncher.body.
  final Paint _bodyPaint = Paint()..color = const Color(0xFFFFD23F);

  @override
  void onLoad() {
    size = Vector2.all(Maze.tileSizeLogical * 2 * (maze.tileSize / Maze.tileSizeLogical));
    _syncPixelPosition();
  }

  /// Queue a buffered direction from the input layer (control-scheme §2).
  /// TODO(Phase 2): consume at next valid tile center; instant reverse.
  void queueDirection(Direction dir) {
    _desiredDir = dir;
  }

  void _syncPixelPosition() {
    // Center of the tile in render space.
    position = Vector2(
      (_tile.col + 0.5) * maze.tileSize,
      (_tile.row + 0.5) * maze.tileSize,
    );
  }

  @override
  void update(double dt) {
    // TODO(Phase 2): advance along _currentDir at the level speed, apply
    // buffered turns at tile centers (±2px tolerance), stop at walls, wrap the
    // tunnel. No per-frame allocation in this loop (NFR-01).
  }

  @override
  void render(Canvas canvas) {
    // Placeholder: a simple disc. Real chomp animation (3-frame ping-pong,
    // rotated by direction) lands with the sprite sheet in Phase 6.
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, _bodyPaint);
  }
}
