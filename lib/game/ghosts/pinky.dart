import 'package:flutter/material.dart';

import '../direction.dart';
import '../ghost.dart';

/// Pinky ("Rosa", pink) — ambush. Targets 4 tiles ahead of the player's facing
/// direction. The classic UP overflow bug is intentional: when the player faces
/// UP the target shifts 4 up *and* 4 left (requirements §4.2, decision D-004).
class Pinky extends Ghost {
  Pinky({required super.maze, required super.startTile})
      : super(
          bodyColor: const Color(0xFFFF8AD8),
          scatterCorner: const TileCoord(2, 0), // top-left (requirements §4.5)
          startsOutside: false, // starts inside, leaves almost immediately (§4.7).
          spriteRow: 1, // Rosa (pink) — row 1 of ghosts.png.
        );

  @override
  TileCoord chaseTarget(TargetContext ctx) {
    var ahead = ctx.playerTile.step(ctx.playerDir, 4);
    if (ctx.playerDir == Direction.up) {
      // Reproduce the original overflow: 4 up AND 4 left.
      ahead = ahead.step(Direction.left, 4);
    }
    return ahead;
  }
}
