import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'maze.dart';

/// The player ("Muncher"). Grid-locked, continuous-speed movement with
/// *buffered* input (requirements §3, control-scheme §2).
///
/// Phase 1 (Skeleton): renders a placeholder gold disc at a start tile. Movement,
/// buffered turns, and the chomp animation are Phase 2 TODOs.
class Pacman extends PositionComponent {
  Pacman({required this.maze, required TileCoord startTile})
      : _tile = startTile,
        super(anchor: Anchor.center);

  final Maze maze;

  /// Base full-speed movement in tiles per second (requirements §3: ~6 t/s).
  /// The effective speed is this times [speedMultiplier], which the game sets
  /// per level from [LevelTuning] (requirements §8).
  static const double speedTilesPerSec = 6.0;

  /// Per-level speed fraction of [speedTilesPerSec] (requirements §8). The game
  /// updates this on level change; defaults to the level-1 value (80%).
  double speedMultiplier = 0.80;

  /// Effective movement speed for this frame (base × level multiplier).
  double get effectiveSpeed => speedTilesPerSec * speedMultiplier;

  /// How close (in logical tiles) to a tile center we must be to act on a turn.
  static const double _centerEpsilon = 0.1;

  /// Current tile (col,row of the tile whose center we are at or moving away
  /// from). Mutated by movement.
  TileCoord _tile;

  /// Direction the player is currently moving.
  Direction _currentDir = Direction.left;

  /// Most recent buffered input. Applied at the next legal tile center
  /// (requirements §3.1). `null` = no pending turn.
  Direction? _desiredDir;

  /// Continuous logical position of the player's center, in *tile* units
  /// (col, row as doubles). The render-space pixel [position] is derived from
  /// this each frame. Kept here to avoid per-frame [TileCoord] churn.
  late double _x = _tile.col + 0.5;
  late double _y = _tile.row + 0.5;

  TileCoord get tile => _tile;
  Direction get currentDir => _currentDir;

  // Style-guide §2: muncher.body.
  final Paint _bodyPaint = Paint()..color = const Color(0xFFFFD23F);

  // --- Sprite animation (Phase 6) ---

  /// Chomp frames 0=closed, 1=small, 2=wide. Ping-pong 0↔1↔2↔1 (§ asset spec).
  /// Injected by the game once the sheet loads; null in headless tests/load
  /// failure -> procedural disc fallback.
  List<Sprite>? chompSprites;

  /// Death animation frames (11), played once when [dying] is set.
  List<Sprite>? deathSprites;

  /// True while the one-shot death animation plays. The game sets this; when the
  /// 11 frames finish, [deathFinished] flips true so the game can respawn.
  bool dying = false;
  bool deathFinished = false;

  /// Chomp ping-pong timing (~0.07s per frame).
  static const double _chompFrameSeconds = 0.07;
  double _chompElapsed = 0;
  // Ping-pong sequence over the three mouth frames.
  static const List<int> _chompSequence = [0, 1, 2, 1];
  int _chompStep = 0;

  /// Death playback timing.
  static const double _deathFrameSeconds = 0.12;
  double _deathElapsed = 0;
  int _deathFrame = 0;

  /// Begin the one-shot death animation. The game freezes other actors and waits
  /// for [deathFinished] before respawning (requirements §7).
  void startDeath() {
    dying = true;
    deathFinished = false;
    _deathElapsed = 0;
    _deathFrame = 0;
  }

  @override
  void onLoad() {
    // One tile wide: the corridors are a single tile, so a 2-tile sprite would
    // visibly spill over the walls on either side. Anchor is center, so the
    // sprite spans its own tile exactly.
    size = Vector2.all(maze.tileSize);
    _syncPixelPosition();
  }

  /// Queue a buffered direction from the input layer (control-scheme §2).
  /// An instant reverse is applied immediately; other turns are consumed at the
  /// next legal tile center.
  void queueDirection(Direction dir) {
    // Instant reverse: legal anywhere along a corridor (requirements §3.1).
    if (dir == _currentDir.opposite) {
      _currentDir = dir;
      _desiredDir = null;
      return;
    }
    _desiredDir = dir;
  }

  /// Reset to a tile center facing left (used on (re)spawn / level start).
  void resetTo(TileCoord startTile) {
    _tile = startTile;
    _currentDir = Direction.left;
    _desiredDir = null;
    _x = _tile.col + 0.5;
    _y = _tile.row + 0.5;
    dying = false;
    deathFinished = false;
    _deathElapsed = 0;
    _deathFrame = 0;
    _chompElapsed = 0;
    _chompStep = 0;
    _syncPixelPosition();
  }

  void _syncPixelPosition() {
    position = Vector2(_x * maze.tileSize, _y * maze.tileSize);
  }

  /// Signed distance (tile units) from ([_x],[_y]) to the center of [_tile]
  /// along the current movement axis. Always >= 0 because we only ever move
  /// from one tile center toward the next.
  double _distToTileCenter() {
    final dx = (_tile.col + 0.5) - _x;
    final dy = (_tile.row + 0.5) - _y;
    return dx.abs() + dy.abs();
  }

  @override
  void update(double dt) {
    // While the death animation plays the player is frozen in place; advance the
    // 11-frame sequence once, then flag completion for the game to respawn.
    if (dying) {
      _deathElapsed += dt;
      if (_deathElapsed >= _deathFrameSeconds) {
        _deathElapsed -= _deathFrameSeconds;
        _deathFrame++;
        final frames = deathSprites?.length ?? 11;
        if (_deathFrame >= frames) {
          _deathFrame = frames - 1;
          deathFinished = true;
        }
      }
      return;
    }

    // Chomp ping-pong (advances regardless of whether the player is blocked, so
    // the mouth keeps animating against a wall — matches the arcade feel).
    _chompElapsed += dt;
    while (_chompElapsed >= _chompFrameSeconds) {
      _chompElapsed -= _chompFrameSeconds;
      _chompStep = (_chompStep + 1) % _chompSequence.length;
    }

    var remaining = effectiveSpeed * dt; // tiles to travel this frame.

    // March in hops, making a turn/stop decision at every tile center. The loop
    // is bounded by the per-frame travel distance (a few tiles), so the guard
    // is just defensive.
    var guard = 0;
    while (remaining > 1e-9 && guard < 16) {
      guard++;

      // If we're (essentially) at the current tile center, make a decision.
      if (_distToTileCenter() <= _centerEpsilon) {
        _x = _tile.col + 0.5; // snap exactly to kill float drift.
        _y = _tile.row + 0.5;

        // (a) Apply a legal buffered turn.
        if (_desiredDir != null && maze.canEnter(_tile, _desiredDir!)) {
          _currentDir = _desiredDir!;
          _desiredDir = null;
        }

        // (b) Stop if the way forward is a wall.
        if (!maze.canEnter(_tile, _currentDir)) {
          break;
        }

        // (c) Commit to the next tile (with tunnel wrap) and move toward its
        // center.
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

      // Advance toward the current tile center, never overshooting it.
      final toCenter = _distToTileCenter();
      final hop = remaining < toCenter ? remaining : toCenter;
      _x += _currentDir.dx * hop;
      _y += _currentDir.dy * hop;
      remaining -= hop;
    }

    _syncPixelPosition();
  }

  /// Rotation (radians) to orient the right-facing sheet toward [_currentDir].
  /// up=-90°, down=+90°, left=180°. Left is rotated rather than flipped so the
  /// chomp mouth opens the right way.
  double get _facingAngle => switch (_currentDir) {
        Direction.right => 0,
        Direction.up => -math.pi / 2,
        Direction.down => math.pi / 2,
        Direction.left => math.pi,
      };

  @override
  void render(Canvas canvas) {
    final death = deathSprites;
    if (dying && death != null && death.isNotEmpty) {
      // Death frames are drawn upright (no rotation) — they animate a collapse.
      final frame = death[_deathFrame.clamp(0, death.length - 1)];
      frame.render(canvas, size: size);
      return;
    }

    final chomp = chompSprites;
    if (chomp != null && chomp.length >= 3) {
      final idx = _chompSequence[_chompStep];
      final sprite = chomp[idx];
      // Rotate around the component centre to face the travel direction.
      canvas.save();
      canvas.translate(size.x / 2, size.y / 2);
      canvas.rotate(_facingAngle);
      canvas.translate(-size.x / 2, -size.y / 2);
      sprite.render(canvas, size: size);
      canvas.restore();
      return;
    }

    // Fallback: a simple disc.
    final r = size.x / 2;
    canvas.drawCircle(Offset(r, r), r, _bodyPaint);
  }
}
