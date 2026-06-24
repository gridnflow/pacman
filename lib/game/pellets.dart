import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'maze.dart';

/// A single pellet or power pellet sitting on a tile (requirements §2).
///
/// Phase 1 (Skeleton): the [PelletField] holds the set and renders placeholder
/// dots; eating, the 244-count placement from the canonical map, and the power
/// blink animation are Phase 3 TODOs.
class Pellet {
  Pellet({required this.tile, required this.isPower});

  final TileCoord tile;
  final bool isPower;
  bool eaten = false;
}

/// Owns all pellets for the current level. One component so we render the whole
/// field cheaply without 244 child components (60fps — NFR-01).
class PelletField extends PositionComponent {
  PelletField({required this.maze});

  final Maze maze;

  /// Keyed by tile for O(1) eat lookup. Populated from the canonical map.
  final Map<TileCoord, Pellet> _pellets = {};

  // Style-guide §2.
  final Paint _pelletPaint = Paint()..color = const Color(0xFFFFE9B0);
  final Paint _powerPaint = Paint()..color = const Color(0xFFFFD23F);

  // --- Sprites (Phase 6) ---

  /// pellets.png cell 0 (regular dot). Injected by the game; null -> fallback.
  Sprite? pelletSprite;

  /// pellets.png cell 1 (power pellet, ON). Blinks against transparency.
  Sprite? powerSprite;

  /// Power-pellet blink period (~0.2s on / off).
  static const double _blinkSeconds = 0.2;
  double _blinkElapsed = 0;
  bool _powerVisible = true;

  int get remaining => _pellets.values.where((p) => !p.eaten).length;

  @override
  void update(double dt) {
    _blinkElapsed += dt;
    while (_blinkElapsed >= _blinkSeconds) {
      _blinkElapsed -= _blinkSeconds;
      _powerVisible = !_powerVisible;
    }
  }

  /// Build all pellets from the maze's parsed pellet layout (the map is the
  /// single source of truth). Called on level start and on refill.
  void loadFromMaze() {
    _pellets.clear();
    for (final spec in maze.pelletSpecs) {
      _pellets[spec.tile] = Pellet(tile: spec.tile, isPower: spec.isPower);
    }
  }

  /// Eat the pellet on [tile] if present and uneaten. Returns the pellet (so the
  /// caller can score 10 vs 50), or null. TODO(Phase 3): wire to player tile.
  Pellet? eatAt(TileCoord tile) {
    final p = _pellets[tile];
    if (p == null || p.eaten) return null;
    p.eaten = true;
    return p;
  }

  /// Sprite draw box: one sprite cell (16px) maps to ~2 logical tiles, centred
  /// on the pellet tile so it reads at the right scale.
  static final Vector2 _spriteSize = Vector2.all(Maze.tileSizeLogical * 2.0);

  @override
  void render(Canvas canvas) {
    for (final p in _pellets.values) {
      if (p.eaten) continue;
      final cx = (p.tile.col + 0.5) * maze.tileSize;
      final cy = (p.tile.row + 0.5) * maze.tileSize;

      if (p.isPower) {
        // Power pellets blink: skip the draw on the "off" half of the cycle.
        if (!_powerVisible) continue;
        final sprite = powerSprite;
        if (sprite != null) {
          sprite.render(
            canvas,
            position: Vector2(cx, cy),
            size: _spriteSize,
            anchor: Anchor.center,
          );
          continue;
        }
      } else {
        final sprite = pelletSprite;
        if (sprite != null) {
          sprite.render(
            canvas,
            position: Vector2(cx, cy),
            size: _spriteSize,
            anchor: Anchor.center,
          );
          continue;
        }
      }

      // Fallback: procedural dot.
      final r = (p.isPower ? 3.0 : 1.0) * (maze.tileSize / Maze.tileSizeLogical);
      canvas.drawCircle(Offset(cx, cy), r, p.isPower ? _powerPaint : _pelletPaint);
    }
  }
}
