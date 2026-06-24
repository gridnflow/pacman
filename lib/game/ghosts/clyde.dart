import 'package:flutter/material.dart';

import '../direction.dart';
import '../ghost.dart';

/// Clyde ("Tango", orange) — shy. Chases directly when 8 or more tiles from the
/// player, but flees to his scatter corner when within 8 tiles, so he oscillates
/// near the player (requirements §4.4). Distances are squared (8² = 64).
class Clyde extends Ghost {
  Clyde({required super.maze, required super.startTile})
      : super(
          bodyColor: const Color(0xFFFFA94D),
          scatterCorner: const TileCoord(0, 31), // bottom-left (§4.5)
          startsOutside: false, // leaves after 60 dots eaten (§4.7).
          spriteRow: 3, // Tango (orange) — row 3 of ghosts.png.
        );

  static const int _fleeRadius2 = 8 * 8; // 64

  @override
  TileCoord chaseTarget(TargetContext ctx) {
    final d2 = tile.dist2(ctx.playerTile);
    return d2 >= _fleeRadius2 ? ctx.playerTile : scatterCorner;
  }
}
