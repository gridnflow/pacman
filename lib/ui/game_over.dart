import 'package:flutter/material.dart';

/// Game-over overlay (style-guide §8.4). Final score, best (with NEW! if beaten),
/// and play-again / menu actions.
///
/// Phase 1 (Skeleton): functional overlay; final styling is a Phase 6 TODO.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.highScore,
    required this.isNewHighScore,
    required this.onPlayAgain,
    required this.onMenu,
  });

  final int score;
  final int highScore;
  final bool isNewHighScore;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  static const Color _panel = Color(0xD913132A); // bg.panel @ ~85%
  static const Color _danger = Color(0xFFFF4D4D);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFFFFD23F);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panel,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('GAME OVER',
                  style: TextStyle(
                      color: _danger, fontSize: 28, letterSpacing: 3)),
              const SizedBox(height: 24),
              Text('SCORE   ${score.toString().padLeft(6, '0')}',
                  style: const TextStyle(color: _primary, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('BEST    ${highScore.toString().padLeft(6, '0')}',
                      style: const TextStyle(color: _primary, fontSize: 14)),
                  if (isNewHighScore)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('NEW!',
                          style: TextStyle(color: _accent, fontSize: 14)),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              _button('PLAY AGAIN', onPlayAgain),
              const SizedBox(height: 12),
              _button('MENU', onMenu),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) {
    return SizedBox(
      height: 44, // min touch target (control-scheme §3)
      width: 200,
      child: ElevatedButton(onPressed: onTap, child: Text(label)),
    );
  }
}
