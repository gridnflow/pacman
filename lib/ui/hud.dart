import 'package:flutter/material.dart';

import '../game/scoring.dart';

/// In-game HUD overlay (style-guide §8.2, control-scheme §3): score + high score
/// top bar with a pause button, lives + fruit bottom bar. Rendered as a Flutter
/// overlay above the Flame world, so it never overlaps the walkable maze.
///
/// Phase 1 (Skeleton): live score/lives/level from [GameState]; fruit icons and
/// final pixel-font styling are later TODOs.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.state, required this.onPause});

  final GameState state;
  final VoidCallback onPause;

  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFFFFD23F);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return Column(
            children: [
              _topBar(),
              const Spacer(),
              _bottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text('SCORE ${state.score.toString().padLeft(6, '0')}',
              style: const TextStyle(color: _primary, fontSize: 12)),
          const Spacer(),
          Text('HIGH ${state.highScore.toString().padLeft(6, '0')}',
              style: const TextStyle(color: _accent, fontSize: 12)),
          const SizedBox(width: 8),
          // 44×44 touch target (control-scheme §3).
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onPause,
              icon: const Icon(Icons.pause, color: _primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Lives: one icon per reserve life (style-guide §8.2). TODO: muncher icon.
          for (var i = 0; i < state.lives; i++)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.circle, color: _accent, size: 12),
            ),
          const Spacer(),
          Text('L${state.level}',
              style: const TextStyle(color: _primary, fontSize: 12)),
        ],
      ),
    );
  }
}
