import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/pacman_game.dart';
import 'game/scoring.dart';
import 'input/swipe_input.dart';
import 'ui/game_over.dart';
import 'ui/hud.dart';
import 'ui/pause.dart';
import 'ui/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait primary (NFR-05).
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );
  runApp(const ChompireApp());
}

class ChompireApp extends StatelessWidget {
  const ChompireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Chompire',
      debugShowCheckedModeBanner: false,
      home: AppRoot(),
    );
  }
}

/// Top-level screen flow: start → game → game-over (style-guide §8,
/// requirements S-09). Kept deliberately simple for the skeleton.
enum _Screen { start, playing }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _Screen _screen = _Screen.start;
  // TODO(Phase 9): load persisted high score via shared_preferences.
  final int _highScore = 0;

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      _Screen.start => StartScreen(
          highScore: _highScore,
          onPlay: () => setState(() => _screen = _Screen.playing),
        ),
      _Screen.playing => GameScreen(
          onExit: () => setState(() => _screen = _Screen.start),
        ),
    };
  }
}

/// Hosts the Flame [PacmanGame] with the HUD and overlays. Phase 1 boots the
/// game and renders the empty maze; gameplay fills in across later phases.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _state = GameState()..reset();
  late final PacmanGame _game = PacmanGame(state: _state);
  bool _paused = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B1A),
      body: Stack(
        children: [
          SwipeInput(
            onDirection: _game.onDirectionInput,
            child: GameWidget(game: _game),
          ),
          Hud(
            state: _state,
            onPause: () => setState(() => _paused = true),
          ),
          if (_paused)
            PauseOverlay(
              onResume: () => setState(() => _paused = false),
              onRestart: () {
                _state.reset();
                setState(() => _paused = false);
              },
              onQuit: widget.onExit,
            ),
          // TODO(Phase 7): show GameOverOverlay when _state.isGameOver. The
          // overlay is imported and ready; wire it to the game-over event.
        ],
      ),
    );
  }
}

// Referenced so the overlay stays linked until Phase 7 wires the game-over
// event. Remove when the real trigger is added.
// ignore: unused_element
Widget _gameOverPreview(GameState state, VoidCallback onMenu) => GameOverOverlay(
      score: state.score,
      highScore: state.highScore,
      isNewHighScore: false,
      onPlayAgain: state.reset,
      onMenu: onMenu,
    );
