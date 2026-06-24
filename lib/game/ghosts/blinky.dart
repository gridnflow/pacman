import 'package:flutter/material.dart';

import '../direction.dart';
import '../ghost.dart';

/// Blinky ("Ember", red) — direct chase. Targets the player's current tile
/// (requirements §4.1).
class Blinky extends Ghost {
  Blinky({required super.maze, required super.startTile})
      : super(
          bodyColor: const Color(0xFFFF4D4D),
          scatterCorner: const TileCoord(25, 0), // top-right (requirements §4.5)
          startsOutside: true, // Blinky begins on the gate path (§4.7).
          spriteRow: 0, // Ember (red) — row 0 of ghosts.png.
        );

  @override
  TileCoord chaseTarget(TargetContext ctx) => ctx.playerTile;
}
