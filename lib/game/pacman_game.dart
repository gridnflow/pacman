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

    // Start tiles are placeholders until the canonical map lands (Phase 2).
    pacman = Pacman(maze: maze, startTile: const TileCoord(14, 23));
    ghosts = [
      Blinky(maze: maze, startTile: const TileCoord(14, 11)),
      Pinky(maze: maze, startTile: const TileCoord(14, 14)),
      Inky(maze: maze, startTile: const TileCoord(12, 14)),
      Clyde(maze: maze, startTile: const TileCoord(16, 14)),
    ];

    world.add(maze);
    world.add(pellets);
    world.add(pacman);
    world.addAll(ghosts);
  }

  /// Feed a buffered direction from the input layer to the player.
  void onDirectionInput(Direction dir) => pacman.queueDirection(dir);

  // TODO(Phase 4+): override update(dt) to advance the global scatter/chase
  // timer, recompute ghost targets, resolve pellet eating, collisions,
  // level-clear, and death. Keep it allocation-free to hold 60fps (NFR-01).
}
