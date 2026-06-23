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

/// Where a ghost lives relative to the house, used to script the simple exit
/// sequence (requirements §4.7). Once [outside], the ghost roams the maze with
/// the normal deterministic turn rule.
enum _HousePhase { inside, leaving, outside }

/// Base ghost: holds the scatter/chase/frightened/eaten FSM, common movement
/// rules (requirements §4.0), and a per-personality chase target.
///
/// Phase 4 (Ghost AI): tile-centered continuous movement, deterministic exit
/// selection (min dist², UP>LEFT>DOWN>RIGHT tie-break, no-up tiles, no 180°
/// reversal except via [forceReverse]), and a simple scripted house exit.
abstract class Ghost extends PositionComponent {
  Ghost({
    required this.maze,
    required this.bodyColor,
    required this.scatterCorner,
    required TileCoord startTile,
    required this.startsOutside,
  })  : _tile = startTile,
        _startTile = startTile,
        _housePhase = startsOutside ? _HousePhase.outside : _HousePhase.inside,
        super(anchor: Anchor.center);

  final Maze maze;
  final Color bodyColor;

  /// Fixed scatter target corner (requirements §4.5).
  final TileCoord scatterCorner;

  /// Whether this ghost begins life already outside the house (Blinky).
  final bool startsOutside;

  /// Movement speed in tiles per second. Slightly slower than the player's 6
  /// (requirements §4.0 / §8 — ghosts are a touch slower than the player).
  static const double speedTilesPerSec = 5.3;

  /// How close (tile units) to a tile center we must be to make a decision.
  static const double _centerEpsilon = 0.1;

  final TileCoord _startTile;

  // Mutated by movement/FSM logic.
  TileCoord _tile;
  Direction _currentDir = Direction.left;
  GhostMode _mode = GhostMode.scatter;
  _HousePhase _housePhase;

  /// Set when an external event (global mode flip / frighten begin) requests a
  /// one-time 180° reversal; consumed at the next tile center.
  bool _reverseQueued = false;

  /// Continuous logical position of the ghost center, in tile units. The pixel
  /// [position] is derived from this each frame (avoids per-frame TileCoord
  /// churn — NFR-01).
  late double _x = _tile.col + 0.5;
  late double _y = _tile.row + 0.5;

  /// The most recently computed chase/scatter target context, refreshed each
  /// frame by the game before [update]. Stored so targeting is recomputed at
  /// tile centers without per-frame allocation in the hot loop.
  TargetContext? _ctx;

  TileCoord get tile => _tile;
  Direction get currentDir => _currentDir;
  GhostMode get mode => _mode;
  bool get isOutsideHouse => _housePhase == _HousePhase.outside;

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

  /// Force a one-time 180° reversal (requirements §5.4). Wired to the global
  /// scatter↔chase flips and (later) the frightened-begin event. Deferred to the
  /// next tile center so the ghost reverses cleanly along the corridor.
  void forceReverse() {
    _reverseQueued = true;
  }

  void setMode(GhostMode mode) {
    _mode = mode;
  }

  /// Provide the latest targeting context (player tile/dir + Blinky tile). Cheap
  /// reference assignment; called once per frame by the game before [update].
  void updateContext(TargetContext ctx) {
    _ctx = ctx;
  }

  /// Begin the scripted house-exit (requirements §4.7). No-op if already out or
  /// already leaving.
  void releaseFromHouse() {
    if (_housePhase == _HousePhase.inside) {
      _housePhase = _HousePhase.leaving;
    }
  }

  /// Reset to the start tile/state on (re)spawn after a life is lost.
  void resetToStart() {
    _tile = _startTile;
    _currentDir = Direction.left;
    _mode = GhostMode.scatter;
    _reverseQueued = false;
    _housePhase = startsOutside ? _HousePhase.outside : _HousePhase.inside;
    _x = _tile.col + 0.5;
    _y = _tile.row + 0.5;
    _syncPixelPosition();
  }

  @override
  void onLoad() {
    size = Vector2.all(maze.tileSize * 2);
    _syncPixelPosition();
  }

  void _syncPixelPosition() {
    position = Vector2(
      (_x) * maze.tileSize,
      (_y) * maze.tileSize,
    );
  }

  double _distToTileCenter() {
    final dx = (_tile.col + 0.5) - _x;
    final dy = (_tile.row + 0.5) - _y;
    return dx.abs() + dy.abs();
  }

  /// The door column this ghost should head to when leaving the house. Both door
  /// tiles (cols 13,14) sit on row 12; aim for the nearer one.
  static const int _doorRow = 12;
  static const int _gateRow = 11;

  @override
  void update(double dt) {
    var remaining = speedTilesPerSec * dt;

    var guard = 0;
    while (remaining > 1e-9 && guard < 16) {
      guard++;

      if (_distToTileCenter() <= _centerEpsilon) {
        _x = _tile.col + 0.5;
        _y = _tile.row + 0.5;

        if (_housePhase == _HousePhase.outside) {
          _decideRoamingDirection();
          if (!maze.ghostCanEnter(_tile, _currentDir)) {
            // Boxed in except for the reverse (rare): take it rather than stop.
            _currentDir = _currentDir.opposite;
            if (!maze.ghostCanEnter(_tile, _currentDir)) break;
          }
        } else {
          // Scripted exit: walk to a door column, then straight up onto the
          // gate path, then declare ourselves outside (requirements §4.7).
          _advanceHouseExit();
        }

        // Commit to the next tile (with tunnel wrap) and move toward its center.
        final raw = _tile.step(_currentDir);
        final wrapped = maze.wrap(raw);
        if (wrapped.col != raw.col) {
          // Tunnel wrap: jump the continuous position to the far side so we
          // approach the new tile's center from the correct edge.
          _x = wrapped.col + 0.5 - _currentDir.dx * 0.5;
          _y = wrapped.row + 0.5 - _currentDir.dy * 0.5;
        }
        _tile = wrapped;
      }

      final toCenter = _distToTileCenter();
      final hop = remaining < toCenter ? remaining : toCenter;
      _x += _currentDir.dx * hop;
      _y += _currentDir.dy * hop;
      remaining -= hop;
    }

    _syncPixelPosition();
  }

  /// Drive the scripted house-exit one decision: set [_currentDir] toward the
  /// next waypoint, flipping to [outside] once on the gate path (§4.7).
  void _advanceHouseExit() {
    final col = _tile.col;
    final row = _tile.row;

    // Reached the gate path above the door -> we are out. Turn into the maze.
    if (row <= _gateRow) {
      _housePhase = _HousePhase.outside;
      _currentDir = Direction.left;
      return;
    }

    // On the door row: go straight up.
    if (row == _doorRow) {
      _currentDir = Direction.up;
      return;
    }

    // Inside the house: first center under a door column (13 or 14), then up.
    const doorColA = 13;
    const doorColB = 14;
    final targetCol = (col - doorColA).abs() <= (col - doorColB).abs()
        ? doorColA
        : doorColB;
    if (col < targetCol) {
      _currentDir = Direction.right;
    } else if (col > targetCol) {
      _currentDir = Direction.left;
    } else {
      _currentDir = Direction.up;
    }
  }

  /// Test seam: place the ghost at [tile] moving [facing] with the given [mode]
  /// and target [ctx], then run a single roaming turn decision and return the
  /// chosen direction. Mirrors what [update] does at a tile center, with no
  /// movement side effects beyond [_currentDir]. (requirements §4.0 / §4.6)
  @visibleForTesting
  Direction chooseDirectionForTest({
    required TileCoord tile,
    required Direction facing,
    required GhostMode mode,
    TargetContext? ctx,
    bool queueReverse = false,
  }) {
    _tile = tile;
    _currentDir = facing;
    _mode = mode;
    _ctx = ctx;
    _reverseQueued = queueReverse;
    _housePhase = _HousePhase.outside;
    _decideRoamingDirection();
    return _currentDir;
  }

  /// At a tile center while roaming: pick the exit minimizing dist² to the
  /// target, excluding the 180° reversal (unless a reverse was queued or it is
  /// the only option) and any forbidden UP (requirements §4.0 / §4.6).
  void _decideRoamingDirection() {
    // Consume a queued forced reversal first (requirements §5.4).
    if (_reverseQueued) {
      _reverseQueued = false;
      _currentDir = _currentDir.opposite;
      return;
    }

    final ctx = _ctx;
    final target = ctx == null ? scatterCorner : targetTile(ctx);
    final back = _currentDir.opposite;
    final applyNoUp = _mode == GhostMode.scatter || _mode == GhostMode.chase;
    final noUpHere = applyNoUp && maze.isNoUpTile(_tile);

    Direction? best;
    int? bestDist;

    // Evaluation order encodes the UP>LEFT>DOWN>RIGHT tie-break: the first
    // candidate at a given (minimal) distance wins because we use strict `<`.
    for (final dir in const [
      Direction.up,
      Direction.left,
      Direction.down,
      Direction.right,
    ]) {
      if (dir == back) continue; // no 180° reversal at will.
      if (dir == Direction.up && noUpHere) continue;
      if (!maze.ghostCanEnter(_tile, dir)) continue;

      final next = maze.wrap(_tile.step(dir));
      final d = next.dist2(target);
      if (bestDist == null || d < bestDist) {
        bestDist = d;
        best = dir;
      }
    }

    if (best != null) {
      _currentDir = best;
    }
    // If no candidate (boxed in except reverse), leave _currentDir; the caller
    // handles the reverse-only dead-end case.
  }

  @override
  void render(Canvas canvas) {
    // Placeholder dome. Real "dome + wavy skirt" sprite with per-direction eyes
    // and frightened/eaten states arrive with the sheet in Phase 6.
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, _paint);
  }
}
