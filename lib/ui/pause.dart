import 'package:flutter/material.dart';

/// Pause overlay (style-guide §8.3). Resume / restart / quit and a sound toggle.
///
/// Phase 1 (Skeleton): functional overlay; final styling is a Phase 6 TODO.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  static const Color _panel = Color(0xD913132A); // bg.panel @ ~85%
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
              const Text('PAUSED',
                  style: TextStyle(
                      color: _accent, fontSize: 28, letterSpacing: 3)),
              const SizedBox(height: 32),
              _button('RESUME', onResume),
              const SizedBox(height: 12),
              _button('RESTART', onRestart),
              const SizedBox(height: 12),
              _button('QUIT', onQuit),
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
