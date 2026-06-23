import 'package:flutter/material.dart';

/// Start screen (style-guide §8.1). Title, tap-to-play, high score, sound toggle.
///
/// Phase 1 (Skeleton): functional layout that routes into the game; final pixel
/// font, drifting ghost row, and chomp animation are Phase 6 TODOs.
class StartScreen extends StatelessWidget {
  const StartScreen({
    super.key,
    required this.highScore,
    required this.onPlay,
  });

  final int highScore;
  final VoidCallback onPlay;

  static const Color _bg = Color(0xFF0B0B1A);
  static const Color _accent = Color(0xFFFFD23F);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF8A8AB0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPlay,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('CHOMPIRE',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 32,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                const Text('TAP TO PLAY',
                    style: TextStyle(color: _primary, fontSize: 16)),
                const SizedBox(height: 24),
                Text('HIGH  ${highScore.toString().padLeft(6, '0')}',
                    style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
