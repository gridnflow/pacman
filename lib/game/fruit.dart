import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'maze.dart';

/// The per-level bonus fruit score tiers (requirements §6.4). The value scales
/// up with the level band. Pure data so it can be unit-tested without Flame.
int fruitPointsForLevel(int level) {
  final l = level < 1 ? 1 : level;
  if (l == 1) return 100;
  if (l == 2) return 300;
  if (l <= 4) return 500; // L3-4
  if (l <= 6) return 700; // L5-6
  if (l <= 8) return 1000; // L7-8
  if (l <= 10) return 2000; // L9-10
  if (l <= 12) return 3000; // L11-12
  return 5000; // L13+
}

/// The dot counts at which the bonus fruit appears for a level (requirements
/// §6.4 — classic 70 / 170 thresholds).
const List<int> kFruitDotThresholds = [70, 170];

/// How long the fruit lingers before vanishing if not collected (§6.4).
const double kFruitLifetimeSeconds = 9.5;

/// The fixed tile the bonus fruit spawns on — the open corridor just below the
/// ghost house (requirements §6.4).
const TileCoord kFruitTile = TileCoord(13, 17);

/// The bonus fruit component (requirements §6.4). Appears on [kFruitTile] for
/// [kFruitLifetimeSeconds]; the game checks collection against the player tile
/// and removes it on pickup or timeout.
///
/// Phase 6 (Polish): renders pellet-sheet cell 3 when a sprite is injected,
/// otherwise a procedural cherry-ish disc fallback so headless tests still pass.
class Fruit extends PositionComponent {
  Fruit({required this.maze, this.sprite})
      : super(anchor: Anchor.center);

  final Maze maze;

  /// Pellet-sheet cell 3, injected by the game once the atlas loads. Null in
  /// headless tests / when the image failed to load -> procedural fallback.
  Sprite? sprite;

  /// Time the fruit has been on screen.
  double elapsed = 0;

  // Procedural fallback palette.
  final Paint _bodyPaint = Paint()..color = const Color(0xFFFF4D4D);
  final Paint _stemPaint = Paint()..color = const Color(0xFF6BD06B);

  @override
  void onLoad() {
    size = Vector2.all(maze.tileSize * 2);
    position = Vector2(
      (kFruitTile.col + 0.5) * maze.tileSize,
      (kFruitTile.row + 0.5) * maze.tileSize,
    );
  }

  @override
  void update(double dt) {
    elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final s = sprite;
    if (s != null) {
      s.render(canvas, size: size);
      return;
    }
    // Fallback: a small disc with a stem so it reads as a fruit.
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r * 1.15), r * 0.5, _bodyPaint);
    canvas.drawRect(
      Rect.fromLTWH(r - r * 0.06, r * 0.4, r * 0.12, r * 0.4),
      _stemPaint,
    );
  }
}
