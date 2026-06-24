import 'package:flutter/material.dart';

import '../direction.dart';
import '../ghost.dart';

/// Inky ("Aqua", cyan) — flank, derived from Blinky (requirements §4.3).
///
/// Take the tile 2 ahead of the player (with the same UP overflow as Pinky),
/// draw a vector from Blinky to that pivot, double it, and target the endpoint:
///   target = 2 * pivot - blinky
class Inky extends Ghost {
  Inky({required super.maze, required super.startTile})
      : super(
          bodyColor: const Color(0xFF4DE1FF),
          scatterCorner: const TileCoord(27, 31), // bottom-right (§4.5)
          startsOutside: false, // leaves after 30 dots eaten (§4.7).
          spriteRow: 2, // Aqua (cyan) — row 2 of ghosts.png.
        );

  @override
  TileCoord chaseTarget(TargetContext ctx) {
    var pivot = ctx.playerTile.step(ctx.playerDir, 2);
    if (ctx.playerDir == Direction.up) {
      pivot = pivot.step(Direction.left, 2); // same UP overflow as Pinky
    }
    // target = pivot + (pivot - blinky) = 2*pivot - blinky
    return pivot * 2 - ctx.blinkyTile;
  }
}
