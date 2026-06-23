import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'direction.dart';
import 'ghost.dart';
import 'ghosts/blinky.dart';
import 'ghosts/clyde.dart';
import 'ghosts/inky.dart';
import 'ghosts/pinky.dart';
import 'level_tuning.dart';
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

  /// True while the frightened window freezes the global scatter/chase timer
  /// (requirements §5.3). Set when a power pellet is eaten, cleared on expiry.
  bool _phaseTimerPaused = false;

  // --- Level tuning (requirements §8) ---

  /// Current level's speed / frightened-window tuning. Refreshed on every level
  /// change via [_applyLevelTuning]; defaults to level 1.
  LevelTuning _tuning = LevelTuning.forLevel(1);

  /// Set true on game over (lives == 0). Freezes the whole game loop so ghosts
  /// and the player stop moving behind the game-over overlay (requirements §7).
  bool _paused = false;

  /// Whether the game loop is frozen (game over). The host reads this to decide
  /// when to show the overlay; setting it true halts actor movement.
  bool get isPaused => _paused;

  // --- Frightened window (requirements §5.3 / §5.5) ---

  /// How long before expiry the ghosts begin flashing (the level-1 "5 flashes"
  /// warning tail), and how fast the white↔blue flash toggles.
  static const double _frightenedFlashWindow = 2;
  static const double _flashPeriod = _frightenedFlashWindow / 10; // 5 on/off.

  /// Seconds left in the frightened window; <=0 means no window active.
  double _frightenedRemaining = 0;
  double _flashElapsed = 0;

  bool get _frightenedActive => _frightenedRemaining > 0;

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

    _applyLevelTuning();
  }

  /// Push the current [_tuning] (derived from [state.level]) onto the actors so
  /// their speeds reflect the level (requirements §8). Called on boot and after
  /// every [GameState.nextLevel].
  void _applyLevelTuning() {
    _tuning = LevelTuning.forLevel(state.level);
    pacman.speedMultiplier = _tuning.playerSpeedMultiplier;
    for (final g in ghosts) {
      g.normalSpeedMultiplier = _tuning.ghostSpeedMultiplier;
      g.frightenedSpeedMultiplier = _tuning.frightenedSpeedMultiplier;
    }
  }

  /// The player's spawn tile. Reused on level clear.
  static const TileCoord _pacmanStart = TileCoord(13, 23);

  /// Feed a buffered direction from the input layer to the player.
  void onDirectionInput(Direction dir) => pacman.queueDirection(dir);

  /// Restart a fresh game after game over ("Play Again"): the caller resets
  /// [state] (score/lives/level), then this refills pellets, returns the actors
  /// to their start positions, re-applies level-1 tuning, and unfreezes the loop
  /// (requirements §7).
  void restart() {
    pellets.loadFromMaze();
    _resetActors();
    _applyLevelTuning();
    _paused = false;
  }

  @override
  void update(double dt) {
    // Game over freezes the loop so actors stop behind the overlay (§7).
    if (_paused || state.isGameOver) return;

    // Provide each ghost with the current targeting context *before* their
    // component update() runs (so turn decisions use fresh data). Cheap, no
    // per-frame allocation beyond the single shared TargetContext.
    _advancePhaseTimer(dt);
    _advanceFrightened(dt);
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
        _beginFrightened();
      } else {
        state.addPellet();
      }
      _dotsEaten++;
      _releaseGhostsByDotCount();
    }

    _resolveGhostCollisions();

    // Level clear: all pellets eaten -> advance to the next level. The maze
    // layout is fixed (D-008, no win state — infinite progression); we refill
    // the pellets, reset the actors, and apply the new level's speed/frightened
    // tuning (requirements §7 / §8).
    if (pellets.remaining == 0) {
      state.nextLevel();
      pellets.loadFromMaze();
      _resetActors();
      _applyLevelTuning();
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

  /// Enter / refresh the frightened window when a power pellet is eaten
  /// (requirements §5.3). All active (outside-the-house) ghosts that aren't
  /// already eaten flip to frightened and reverse once; the global phase timer
  /// freezes; the eat-chain resets to 200. Re-eating refreshes the full 6s.
  void _beginFrightened() {
    state.startGhostChain();

    // L9+ have no frightened window (§8): outside ghosts still reverse once, but
    // they never turn blue and remain deadly. The +50 power-pellet score was
    // already awarded by the caller.
    if (!_tuning.hasFrightened) {
      for (final g in ghosts) {
        if (g.mode == GhostMode.eaten) continue;
        if (!g.isOutsideHouse) continue;
        g.forceReverse(); // reverse only (§5.4); no frighten.
      }
      return;
    }

    _frightenedRemaining = _tuning.frightenedSeconds;
    _flashElapsed = 0;
    _phaseTimerPaused = true;

    for (final g in ghosts) {
      if (g.mode == GhostMode.eaten) continue; // eyes keep heading home (§5.6).
      if (!g.isOutsideHouse) continue; // ghosts still inside are not frightened.
      final wasFrightened = g.mode == GhostMode.frightened;
      g.setMode(GhostMode.frightened);
      g.frightenedFlashing = false;
      if (!wasFrightened) g.forceReverse(); // reverse only on entry (§5.4).
    }
  }

  /// Tick the frightened window each frame (requirements §5.5): drive the flash
  /// warning tail, and on expiry restore frightened ghosts to the current global
  /// phase mode and unfreeze the timer. Also revives eaten "eyes" once home.
  void _advanceFrightened(double dt) {
    // Revive eaten ghosts that have reached the house, independent of the timer.
    final (currentMode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      if (g.hasReachedHouse) g.reviveAtHouse(currentMode);
    }

    if (!_frightenedActive) return;

    _frightenedRemaining -= dt;
    if (_frightenedRemaining <= 0) {
      _endFrightened();
      return;
    }

    // Flash white↔blue during the warning tail before expiry. Cap the tail at
    // the window length so very short (L6-8 = 1s) windows still flash sanely.
    final flashWindow = _frightenedFlashWindow < _tuning.frightenedSeconds
        ? _frightenedFlashWindow
        : _tuning.frightenedSeconds;
    final flashing = _frightenedRemaining <= flashWindow;
    if (flashing) {
      _flashElapsed += dt;
      final on = (_flashElapsed ~/ _flashPeriod).isEven;
      for (final g in ghosts) {
        if (g.mode == GhostMode.frightened) g.frightenedFlashing = on;
      }
    }
  }

  /// End the frightened window: frightened ghosts return to the current global
  /// phase mode and the scatter/chase timer resumes (requirements §5.5).
  void _endFrightened() {
    _frightenedRemaining = 0;
    _flashElapsed = 0;
    _phaseTimerPaused = false;
    final (mode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      if (g.mode != GhostMode.frightened) continue;
      g.setMode(mode);
      g.frightenedFlashing = false;
    }
  }

  /// Release Inky/Clyde once enough dots have been eaten (per-ghost counter,
  /// D-006 v1). [ghosts] order is Blinky, Pinky, Inky, Clyde.
  void _releaseGhostsByDotCount() {
    if (_dotsEaten >= _inkyDotThreshold) ghosts[2].releaseFromHouse();
    if (_dotsEaten >= _clydeDotThreshold) ghosts[3].releaseFromHouse();
  }

  /// Resolve player↔ghost tile overlaps (requirements §4 / §5). A frightened
  /// ghost is eaten (score chain + becomes "eyes"); an eaten ghost is harmless;
  /// any other (scatter/chase) ghost costs a life.
  void _resolveGhostCollisions() {
    for (final g in ghosts) {
      if (g.tile != pacman.tile) continue;

      if (g.mode == GhostMode.eaten) continue; // eyes are harmless.

      if (g.mode == GhostMode.frightened) {
        state.eatGhost(); // 200/400/800/1600 chain (requirements §6.2).
        g.setMode(GhostMode.eaten); // race home as eyes; not a life loss.
        continue; // several ghosts can be eaten on the same frame.
      }

      state.loseLife();
      if (!state.isGameOver) {
        _resetActors();
      }
      return; // one deadly collision per frame is enough.
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
    _frightenedRemaining = 0;
    _flashElapsed = 0;
    _phaseTimerPaused = false;
    final (mode, _) = _phaseSchedule[_phaseIndex];
    for (final g in ghosts) {
      g.setMode(mode);
    }
    ghosts[1].releaseFromHouse(); // Pinky out again.
  }
}
