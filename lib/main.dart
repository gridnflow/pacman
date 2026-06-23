import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/pacman_game.dart';
import 'game/scoring.dart';
import 'input/swipe_input.dart';
import 'ui/game_over.dart';
import 'ui/hud.dart';
import 'ui/pause.dart';
import 'ui/start_screen.dart';

/// shared_preferences key for the persisted high score (requirements §7).
const String kHighScoreKey = 'chompire.highScore';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait primary (NFR-05).
  await SystemChrome.setPreferredOrientations(
    const [DeviceOrientation.portraitUp],
  );

  // Load the persisted high score before the first frame so the start screen
  // and the game both open with the correct best (shared_preferences supports
  // web). Failures (e.g. unavailable storage) fall back to 0.
  var highScore = 0;
  try {
    final prefs = await SharedPreferences.getInstance();
    highScore = prefs.getInt(kHighScoreKey) ?? 0;
  } catch (_) {
    highScore = 0;
  }

  runApp(ChompireApp(initialHighScore: highScore));
}

class ChompireApp extends StatelessWidget {
  const ChompireApp({super.key, this.initialHighScore = 0});

  final int initialHighScore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chompire',
      debugShowCheckedModeBanner: false,
      home: AppRoot(initialHighScore: initialHighScore),
    );
  }
}

/// Top-level screen flow: start → game → game-over (style-guide §8,
/// requirements S-09). Kept deliberately simple for the skeleton.
enum _Screen { start, playing }

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, this.initialHighScore = 0});

  final int initialHighScore;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  _Screen _screen = _Screen.start;
  late int _highScore = widget.initialHighScore;

  /// Persist a new high score (called from the game) and reflect it on the start
  /// screen. Writes are fire-and-forget; storage errors are non-fatal.
  Future<void> _persistHighScore(int value) async {
    if (mounted) setState(() => _highScore = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kHighScoreKey, value);
    } catch (_) {
      // Best-effort persistence; ignore storage failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_screen) {
      _Screen.start => StartScreen(
          highScore: _highScore,
          onPlay: () => setState(() => _screen = _Screen.playing),
        ),
      _Screen.playing => GameScreen(
          highScore: _highScore,
          onHighScoreChanged: _persistHighScore,
          onExit: () => setState(() => _screen = _Screen.start),
        ),
    };
  }
}

/// Hosts the Flame [PacmanGame] with the HUD and overlays. Phase 1 boots the
/// game and renders the empty maze; gameplay fills in across later phases.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.onExit,
    required this.highScore,
    required this.onHighScoreChanged,
  });

  final VoidCallback onExit;

  /// High score at the moment this game started — used to decide NEW! on the
  /// game-over screen (requirements §7).
  final int highScore;

  /// Persist callback invoked whenever the game beats the high score.
  final ValueChanged<int> onHighScoreChanged;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _state = GameState(
    onHighScoreChanged: widget.onHighScoreChanged,
  )
    ..loadHighScore(widget.highScore)
    ..reset();
  late final PacmanGame _game = PacmanGame(state: _state);
  bool _paused = false;

  /// The high score the current run started against, so "this run beat it" is
  /// true only when the live score exceeds it (requirements §7).
  late final int _startHighScore = widget.highScore;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  /// Rebuild on game-over so the [GameOverOverlay] appears (the game loop itself
  /// freezes via [PacmanGame.update]'s isGameOver guard).
  void _onStateChanged() {
    if (_state.isGameOver && mounted) setState(() {});
  }

  void _playAgain() {
    _state.reset();
    _game.restart();
    setState(() => _paused = false);
  }

  @override
  Widget build(BuildContext context) {
    final isGameOver = _state.isGameOver;
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
          if (_paused && !isGameOver)
            PauseOverlay(
              onResume: () => setState(() => _paused = false),
              onRestart: _playAgain,
              onQuit: widget.onExit,
            ),
          if (isGameOver)
            GameOverOverlay(
              score: _state.score,
              highScore: _state.highScore,
              isNewHighScore: _state.score > _startHighScore,
              onPlayAgain: _playAgain,
              onMenu: widget.onExit,
            ),
        ],
      ),
    );
  }
}
