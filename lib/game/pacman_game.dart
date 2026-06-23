import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'ghost.dart';
import 'ghosts/blinky.dart';
import 'ghosts/clyde.dart';
import 'ghosts/inky.dart';
import 'ghosts/pinky.dart';
import 'maze.dart';
import 'pacman.dart';
import 'pellets.dart';
import 'scoring.dart';

/// The root [FlameGame]: owns the world, the actors, and (later) the global
/// scatter/chase FSM and level flow. Architecture per PROJECT_PLAN §4.
///
/// Phase 1 (Skeleton): builds the world, fits the camera to the logical
/// 224×248 canvas (style-guide §1), and renders an empty maze with placeholder
/// actors. The game loop's state machine is filled in across Phases 2–7.
class PacmanGame extends FlameGame {
  PacmanGame({GameState? state})
      : state = state ?? GameState();

  /// Render scale: logical px → render px. Camera fits the logical canvas so
  /// everything below works in logical (8px-tile) units. Integer-friendly.
  static const double renderTileSize = Maze.tileSizeLogical * 1.0;

  /// Logical canvas (style-guide §1): 28*8 × 31*8 plus HUD rows are handled by
  /// the Flutter HUD overlay, not the world. We fit just the maze playfield.
  static const double logicalWidth = Maze.gridCols * renderTileSize; // 224
  static const double logicalHeight = Maze.gridRows * renderTileSize; // 248

  final GameState state;

  late final Maze maze;
  late final PelletField pellets;
  late final Pacman pacman;
  late final List<Ghost> ghosts;
  late final Blinky _blinky;

  // --- Global scatter/chase phase timer (requirements §5.2) ---

  /// Level-1 schedule in (mode, seconds). A `null` duration means "stay here
  /// forever" (the final chase band). Frightened time pauses this timer — that
  /// hook lands with Phase 5; for now nothing pauses it.
  static const List<(GhostMode, double?)> _phaseSchedule = [
    (GhostMode.scatter, 7),
    (GhostMode.chase, 20),
    (GhostMode.scatter, 7),
    (GhostMode.chase, 20),
    (GhostMode.scatter, 5),
    (GhostMode.chase, 20),
    (GhostMode.scatter, 5),
    (GhostMode.chase, null), // chase forever.
  ];

  int _phaseIndex = 0;
  double _phaseElapsed = 0;

  /// True while the (future) frightened window should freeze the phase timer.
  /// Phase 5 will set this; kept here so the structure exists now.
  final bool _phaseTimerPaused = false;

  /// Per-ghost dot-counter release thresholds (requirements §4.7 / D-006, v1
  /// per-ghost counter). Inky leaves after 30 dots, Clyde after 60. Pinky
  /// leaves immediately.
  static const int _inkyDotThreshold = 30;
  static const int _clydeDotThreshold = 60;
  int _dotsEaten = 0;

  @override
  Color backgroundColor() => const Color(0xFF0B0B1A); // bg.deep

  @override
  Future<void> onLoad() async {
    // Fit the logical maze canvas to the viewport, letterboxing as needed
    // (style-guide §1: integer scale, pixel-crisp).
    camera = CameraComponent.withFixedResolution(
      width: logicalWidth,
      height: logicalHeight,
    );
    camera.viewfinder.anchor = Anchor.topLeft;

    maze = Maze(tileSize: renderTileSize);
    pellets = PelletField(maze: maze)..loadFromMaze();

    pacman = Pacman(maze: maze, startTile: _pacmanStart);
    _blinky = Blinky(maze: maze, startTile: const TileCoord(14, 11));
    ghosts = [
      _blinky,
      Pinky(maze: maze, startTile: const TileCoord(14, 14)),
      Inky(maze: maze, startTile: const TileCoord(12, 14)),
      Clyde(maze: maze, startTile: const TileCoord(16, 14)),
    ];

    world.add(maze);
    world.add(pellets);
    world.add(pacman);
    world.addAll(ghosts);

    // Apply the opening phase mode and release Pinky right away (§4.7).
    final (mode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      g.setMode(mode);
    }
    ghosts[1].releaseFromHouse(); // Pinky leaves almost immediately.
  }

  /// The player's spawn tile. Reused on level clear.
  static const TileCoord _pacmanStart = TileCoord(13, 23);

  /// Feed a buffered direction from the input layer to the player.
  void onDirectionInput(Direction dir) => pacman.queueDirection(dir);

  @override
  void update(double dt) {
    // Provide each ghost with the current targeting context *before* their
    // component update() runs (so turn decisions use fresh data). Cheap, no
    // per-frame allocation beyond the single shared TargetContext.
    _advancePhaseTimer(dt);
    final ctx = TargetContext(
      playerTile: pacman.tile,
      playerDir: pacman.currentDir,
      blinkyTile: _blinky.tile,
    );
    for (final g in ghosts) {
      g.updateContext(ctx);
    }

    super.update(dt); // advances component update()s (player + ghost movement).

    // Resolve pellet eating from the player's current tile.
    final eaten = pellets.eatAt(pacman.tile);
    if (eaten != null) {
      if (eaten.isPower) {
        state.addPowerPellet();
      } else {
        state.addPellet();
      }
      _dotsEaten++;
      _releaseGhostsByDotCount();
    }

    _resolveGhostCollisions();

    // Level clear: all pellets eaten -> refill and reset positions. Ghost FSM /
    // proper level flow lands in a later phase; a simple refill is enough to
    // keep the field playable.
    if (pellets.remaining == 0) {
      pellets.loadFromMaze();
      _resetActors();
    }
  }

  /// Drive the single global scatter↔chase timer (requirements §5.2). On a phase
  /// flip, push the new mode to every non-frightened ghost and force a one-time
  /// 180° reversal (requirements §5.4).
  void _advancePhaseTimer(double dt) {
    if (_phaseTimerPaused) return;
    final (_, duration) = _phaseSchedule[_phaseIndex];
    if (duration == null) return; // final band: chase forever.

    _phaseElapsed += dt;
    if (_phaseElapsed < duration) return;

    _phaseElapsed = 0;
    _phaseIndex++;
    final (nextMode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      if (g.mode == GhostMode.frightened || g.mode == GhostMode.eaten) continue;
      g.setMode(nextMode);
      g.forceReverse();
    }
  }

  /// Release Inky/Clyde once enough dots have been eaten (per-ghost counter,
  /// D-006 v1). [ghosts] order is Blinky, Pinky, Inky, Clyde.
  void _releaseGhostsByDotCount() {
    if (_dotsEaten >= _inkyDotThreshold) ghosts[2].releaseFromHouse();
    if (_dotsEaten >= _clydeDotThreshold) ghosts[3].releaseFromHouse();
  }

  /// Lose a life and reset on player↔ghost tile overlap (requirements §4 / §5).
  /// Frightened/eaten ghosts are not deadly (frightened arrives in Phase 5).
  void _resolveGhostCollisions() {
    for (final g in ghosts) {
      if (g.mode == GhostMode.frightened || g.mode == GhostMode.eaten) continue;
      if (g.tile != pacman.tile) continue;

      state.loseLife();
      if (!state.isGameOver) {
        _resetActors();
      }
      return; // one collision per frame is enough.
    }
  }

  /// Reset the player and all ghosts to their start positions, and restart the
  /// global phase timer (used on death-respawn and level clear).
  void _resetActors() {
    pacman.resetTo(_pacmanStart);
    for (final g in ghosts) {
      g.resetToStart();
    }
    _phaseIndex = 0;
    _phaseElapsed = 0;
    _dotsEaten = 0;
    final (mode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      g.setMode(mode);
    }
    ghosts[1].releaseFromHouse(); // Pinky out again.
  }
}
