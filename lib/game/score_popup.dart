import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A short-lived floating score number (requirements §6.2 / §6.4). Spawned at
/// the tile where a ghost was eaten (200/400/800/1600) or a fruit was collected,
/// it drifts upward while fading out over ~0.5s, then removes itself.
///
/// Phase 6 (Polish): pure procedural text — no sprite sheet needed. Added to the
/// world so it sits in maze-logical coordinates like the actors.
class ScorePopup extends PositionComponent {
  ScorePopup({
    required this.points,
    required Vector2 position,
    this.color = const Color(0xFF8BE9FF),
  }) : super(position: position, anchor: Anchor.center);

  /// The number to show.
  final int points;

  /// Text fill colour (cyan for ghosts, peach for fruit — caller picks).
  final Color color;

  /// Total lifetime in seconds before self-removal.
  static const double _lifetime = 0.5;

  /// Upward drift over the lifetime, in logical pixels.
  static const double _riseLogical = 8.0;

  double _elapsed = 0;

  @override
  void update(double dt) {
    _elapsed += dt;
    // Drift upward proportionally to elapsed time.
    position.y -= _riseLogical * (dt / _lifetime);
    if (_elapsed >= _lifetime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _lifetime).clamp(0.0, 1.0);
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    final painter = TextPainter(
      text: TextSpan(
        text: '$points',
        style: TextStyle(
          // Small, crisp number sized in logical pixels.
          fontSize: 6,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centre the text on the component origin.
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  }
}
