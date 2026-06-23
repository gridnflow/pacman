import 'package:flutter/foundation.dart';

/// Score, lives, and level state. Plain Dart (no Flame) so it is trivially
/// unit-testable per requirements §6 / §7. Uses [ChangeNotifier] so the HUD can
/// rebuild without the game loop pushing values every frame.
class GameState extends ChangeNotifier {
  GameState({this.startingLives = 3, this.onHighScoreChanged});

  /// Invoked whenever [highScore] increases, so the host can persist it (e.g.
  /// to shared_preferences). Plain callback keeps this class Flutter/storage
  /// agnostic and unit-testable (requirements §7).
  final void Function(int highScore)? onHighScoreChanged;

  // --- Score table (requirements §6.1) ---
  static const int pelletPoints = 10;
  static const int powerPelletPoints = 50;
  static const List<int> ghostChain = [200, 400, 800, 1600];
  static const int extraLifeThreshold = 10000;

  final int startingLives;

  int _score = 0;
  int _lives = 0;
  int _level = 1;
  int _highScore = 0;

  /// Index into [ghostChain] for the current frightened window. Reset to 0 each
  /// time a new power pellet starts a frightened window (requirements §6.2).
  int _chainIndex = 0;

  bool _extraLifeAwarded = false;

  int get score => _score;
  int get lives => _lives;
  int get level => _level;
  int get highScore => _highScore;

  void reset() {
    _score = 0;
    _lives = startingLives;
    _level = 1;
    _chainIndex = 0;
    _extraLifeAwarded = false;
    notifyListeners();
  }

  void loadHighScore(int value) {
    _highScore = value;
    notifyListeners();
  }

  void addPellet() => _addScore(pelletPoints);

  void addPowerPellet() => _addScore(powerPelletPoints);

  /// Begin a new frightened window's eat-chain (requirements §6.2).
  void startGhostChain() => _chainIndex = 0;

  /// Award the next ghost in the current chain and advance. Returns the points
  /// awarded (200/400/800/1600). A 5th call clamps to the last value but cannot
  /// occur in practice (only four ghosts).
  int eatGhost() {
    final idx = _chainIndex.clamp(0, ghostChain.length - 1);
    final points = ghostChain[idx];
    if (_chainIndex < ghostChain.length - 1) _chainIndex++;
    _addScore(points);
    return points;
  }

  /// Award fruit points (value comes from the level tier; requirements §6.4).
  void addFruit(int points) => _addScore(points);

  void loseLife() {
    if (_lives > 0) _lives--;
    notifyListeners();
  }

  bool get isGameOver => _lives <= 0;

  void nextLevel() {
    _level++;
    notifyListeners();
  }

  void _addScore(int points) {
    _score += points;
    // One-time extra life at the threshold (requirements §6.5).
    if (!_extraLifeAwarded && _score >= extraLifeThreshold) {
      _extraLifeAwarded = true;
      _lives++;
    }
    if (_score > _highScore) {
      _highScore = _score;
      onHighScoreChanged?.call(_highScore);
    }
    notifyListeners();
  }
}
