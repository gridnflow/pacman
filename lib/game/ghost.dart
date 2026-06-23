import 'dart:math';

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
    int frightenSeed = 0x6d6e63, // 'mnc' — fixed so wander is reproducible.
  })  : _tile = startTile,
        _startTile = startTile,
        _housePhase = startsOutside ? _HousePhase.outside : _HousePhase.inside,
        _rng = Random(frightenSeed),
        super(anchor: Anchor.center);

  final Maze maze;
  final Color bodyColor;

  /// Fixed scatter target corner (requirements §4.5).
  final TileCoord scatterCorner;

  /// Whether this ghost begins life already outside the house (Blinky).
  final bool startsOutside;

  /// Normal (scatter/chase) movement speed in tiles per second. Slightly slower
  /// than the player's 6 (requirements §4.0 / §8 — ghosts are a touch slower).
  static const double normalSpeedTilesPerSec = 5.3;

  /// Frightened speed (requirements §8 — level-1 frightened ghosts move at ~50%
  /// of base; we use a touch higher so they still feel chase-able but slow).
  static const double frightenedSpeedTilesPerSec = 3.2;

  /// Eaten "eyes" return-to-house speed — the fastest state so the player gets
  /// the ghost back into rotation quickly (requirements §5.6).
  static const double eatenSpeedTilesPerSec = 8.0;

  /// Per-level speed fractions of the base constants (requirements §8). The game
  /// sets these on level change from [LevelTuning]; defaults reproduce level 1.
  double normalSpeedMultiplier = 0.75;
  double frightenedSpeedMultiplier = 0.50;

  /// Speed for the current [mode]. Variable so frightened slows and eaten dashes
  /// home (requirements §5.5 / §5.6 / §8). Normal and frightened speeds scale by
  /// the level multipliers; eaten "eyes" always dash home at full speed.
  double get speedTilesPerSec => switch (_mode) {
        GhostMode.frightened =>
          frightenedSpeedTilesPerSec * frightenedSpeedMultiplier,
        GhostMode.eaten => eatenSpeedTilesPerSec,
        _ => normalSpeedTilesPerSec * normalSpeedMultiplier,
      };

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

  /// Seeded PRNG driving frightened wander (requirements §5.5). Fixed seed at
  /// construction so a given game is reproducible.
  final Random _rng;

  /// When true the render layer flashes the frightened body white↔blue to warn
  /// the window is about to end (requirements §5.5, level-1 5-flash tail). The
  /// game owns the timing and toggles this each blink.
  bool _frightenedFlashing = false;

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

  /// Whether the frightened body should currently flash white (set by the game
  /// during the warning tail of the frightened window).
  bool get isFlashing => _frightenedFlashing;
  set frightenedFlashing(bool v) => _frightenedFlashing = v;

  /// The house-door target tile eaten "eyes" return to (requirements §5.6).
  static const TileCoord houseDoorTile = TileCoord(13, _doorRow);

  /// True once an [eaten] ghost has arrived back at the house door, so the game
  /// can revive it into the current global mode (requirements §5.6).
  bool get hasReachedHouse =>
      _mode == GhostMode.eaten && _tile == houseDoorTile;

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
        // Frightened ghosts do not target a tile — they wander pseudo-randomly
        // (handled in [_decideRoamingDirection]); the value here is unused.
        GhostMode.frightened => scatterCorner,
        // Eaten "eyes" race back to the house door (requirements §5.6).
        GhostMode.eaten => houseDoorTile,
      };

  /// Force a one-time 180° reversal (requirements §5.4). Wired to the global
  /// scatter↔chase flips and (later) the frightened-begin event. Deferred to the
  /// next tile center so the ghost reverses cleanly along the corridor.
  void forceReverse() {
    _reverseQueued = true;
  }

  void setMode(GhostMode mode) {
    _mode = mode;
    if (mode != GhostMode.frightened) _frightenedFlashing = false;
  }

  /// Provide the latest targeting context (player tile/dir + Blinky tile). Cheap
  /// reference assignment; called once per frame by the game before [update].
  void updateContext(TargetContext ctx) {
    _ctx = ctx;
  }

  /// Revive an eaten ghost that has reached the house door (requirements §5.6):
  /// drop it just inside the house in [mode], then re-run the scripted exit so
  /// it walks back out as a normal ghost. Used by the game on [hasReachedHouse].
  void reviveAtHouse(GhostMode mode) {
    _tile = const TileCoord(14, 14); // inside the house.
    _x = _tile.col + 0.5;
    _y = _tile.row + 0.5;
    _currentDir = Direction.up;
    _mode = mode;
    _frightenedFlashing = false;
    _reverseQueued = false;
    _housePhase = _HousePhase.leaving;
    _syncPixelPosition();
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
    _frightenedFlashing = false;
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

        if (_mode == GhostMode.eaten) {
          // Eaten "eyes" home in on the house door, then stop on it (the game
          // revives them next frame via [hasReachedHouse]) (requirements §5.6).
          if (_tile == houseDoorTile) break;
          _advanceEatenReturn();
        } else if (_housePhase == _HousePhase.outside) {
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

  /// Whether an eaten ghost (eyes) may move [dir] from [c]. Unlike a roaming
  /// ghost, the eyes may pass through the house door to get home.
  bool _eatenCanEnter(TileCoord c, Direction dir) {
    final next = maze.wrap(c.step(dir));
    final t = maze.tileAtCoord(next);
    return t != TileType.wall && t != TileType.house;
  }

  /// Steer eaten "eyes" toward [houseDoorTile] (requirements §5.6): greedy
  /// min-dist² over enterable exits, excluding the 180° reversal unless it is
  /// the only way out. No no-up/frighten constraints apply to the eyes.
  void _advanceEatenReturn() {
    // On the gate corridor directly above the door: step down through it.
    if (_tile.row == _gateRow && _tile.col == houseDoorTile.col) {
      _currentDir = Direction.down;
      return;
    }

    final back = _currentDir.opposite;
    Direction? best;
    int? bestDist;
    for (final dir in const [
      Direction.up,
      Direction.left,
      Direction.down,
      Direction.right,
    ]) {
      if (dir == back) continue;
      if (!_eatenCanEnter(_tile, dir)) continue;
      final next = maze.wrap(_tile.step(dir));
      final d = next.dist2(houseDoorTile);
      if (bestDist == null || d < bestDist) {
        bestDist = d;
        best = dir;
      }
    }
    if (best != null) {
      _currentDir = best;
    } else if (_eatenCanEnter(_tile, back)) {
      _currentDir = back; // dead-end: reverse is the only way.
    }
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

    // Frightened: pick a pseudo-random legal exit (no 180° reversal) using the
    // seeded PRNG so the wander is reproducible (requirements §5.5).
    if (_mode == GhostMode.frightened) {
      _decideFrightenedDirection();
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

  /// Frightened wander (requirements §5.5): from the legal exits (no 180°
  /// reversal, honoring walls/house) pick one uniformly via the seeded [_rng].
  /// Deterministic for a fixed seed + sequence of intersections.
  void _decideFrightenedDirection() {
    final back = _currentDir.opposite;
    final options = <Direction>[];
    for (final dir in const [
      Direction.up,
      Direction.left,
      Direction.down,
      Direction.right,
    ]) {
      if (dir == back) continue; // no 180° reversal at will.
      if (!maze.ghostCanEnter(_tile, dir)) continue;
      options.add(dir);
    }
    if (options.isNotEmpty) {
      _currentDir = options[_rng.nextInt(options.length)];
    }
    // Boxed in except reverse: leave _currentDir; the caller takes the reverse.
  }

  // Frightened/eaten render palette (requirements §5.5 / §6.2).
  static const Color _frightenedColor = Color(0xFF2C5FE0);
  static const Color _frightenedFlashColor = Color(0xFFFFFFFF);
  static const Color _eyeColor = Color(0xFFFFFFFF);

  late final Paint _frightenedPaint = Paint()..color = _frightenedColor;
  late final Paint _frightenedFlashPaint = Paint()..color = _frightenedFlashColor;
  late final Paint _eyePaint = Paint()..color = _eyeColor;

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;

    if (_mode == GhostMode.eaten) {
      // Only the eyes remain, racing home (requirements §5.6).
      final eyeR = r * 0.22;
      canvas.drawCircle(Offset(r - eyeR * 1.6, r), eyeR, _eyePaint);
      canvas.drawCircle(Offset(r + eyeR * 1.6, r), eyeR, _eyePaint);
      return;
    }

    if (_mode == GhostMode.frightened) {
      final body = _frightenedFlashing ? _frightenedFlashPaint : _frightenedPaint;
      canvas.drawCircle(Offset(r, r), r, body);
      return;
    }

    // Placeholder dome. Real "dome + wavy skirt" sprite with per-direction eyes
    // arrives with the sheet in Phase 6.
    canvas.drawCircle(Offset(r, r), r, _paint);
  }
}
