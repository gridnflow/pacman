import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'maze.dart';

/// The shared finite-state machine modes for all ghosts (requirements §5.1).
enum GhostMode { scatter, chase, frightened, eaten }

/// Snapshot of everything a ghost needs to compute its chase target. Passed in
/// rather than reaching into globals, so targeting is a pure, unit-testable
/// function (requirements §4.8 — the highest-value correctness risk).
class TargetContext {
  const TargetContext({
    required this.playerTile,
    required this.playerDir,
    required this.blinkyTile,
  });

  final TileCoord playerTile;
  final Direction playerDir;

  /// Blinky's live tile — Inky's target depends on it (requirements §4.3).
  final TileCoord blinkyTile;
}

/// Base ghost: holds the scatter/chase/frightened/eaten FSM, common movement
/// rules (requirements §4.0), and a per-personality chase target.
///
/// Phase 1 (Skeleton): renders a placeholder colored body at its start tile and
/// exposes the targeting interface. The FSM transitions, deterministic turn
/// selection, no-up tiles, frightened PRNG, and movement are Phase 4 TODOs.
abstract class Ghost extends PositionComponent {
  Ghost({
    required this.maze,
    required this.bodyColor,
    required this.scatterCorner,
    required TileCoord startTile,
  })  : _tile = startTile,
        super(anchor: Anchor.center);

  final Maze maze;
  final Color bodyColor;

  /// Fixed scatter target corner (requirements §4.5).
  final TileCoord scatterCorner;

  // These are mutated by movement/FSM logic landing in Phase 4; not final.
  // ignore: prefer_final_fields
  TileCoord _tile;
  Direction _currentDir = Direction.left;
  GhostMode _mode = GhostMode.scatter;

  TileCoord get tile => _tile;
  Direction get currentDir => _currentDir;
  GhostMode get mode => _mode;

  late final Paint _paint = Paint()..color = bodyColor;

  /// Per-personality chase target tile (requirements §4.1–4.4). Pure function of
  /// [ctx] — unit-tested per ghost. This is the heart of each personality.
  TileCoord chaseTarget(TargetContext ctx);

  /// The target tile for the current [mode]. In scatter the ghost heads to its
  /// [scatterCorner]; in chase it uses [chaseTarget]. Frightened/eaten targeting
  /// is handled separately (requirements §5.5 / §5.6) — TODO(Phase 5/4).
  TileCoord targetTile(TargetContext ctx) => switch (_mode) {
        GhostMode.scatter => scatterCorner,
        GhostMode.chase => chaseTarget(ctx),
        GhostMode.frightened => scatterCorner, // TODO(Phase 5): PRNG wander.
        GhostMode.eaten => scatterCorner, // TODO(Phase 4): house door.
      };

  /// Force a one-time 180° reversal (requirements §5.4). TODO(Phase 4): wire to
  /// the global scatter↔chase flips and the frightened-begin event.
  void forceReverse() {
    _currentDir = _currentDir.opposite;
  }

  void setMode(GhostMode mode) {
    _mode = mode;
  }

  @override
  void onLoad() {
    size = Vector2.all(maze.tileSize * 2);
    _syncPixelPosition();
  }

  void _syncPixelPosition() {
    position = Vector2(
      (_tile.col + 0.5) * maze.tileSize,
      (_tile.row + 0.5) * maze.tileSize,
    );
  }

  @override
  void update(double dt) {
    // TODO(Phase 4): at each tile center pick the exit minimizing
    // dist²(next, target) excluding 180° reversal, with UP>LEFT>DOWN>RIGHT
    // tie-break and no-up-tile constraint. Move at the level/mode speed. No
    // per-frame allocation (NFR-01).
  }

  @override
  void render(Canvas canvas) {
    // Placeholder dome. Real "dome + wavy skirt" sprite with per-direction eyes
    // and frightened/eaten states arrive with the sheet in Phase 6.
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, _paint);
  }
}
