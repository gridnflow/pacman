/// Per-level difficulty tuning (requirements §8). The maze layout is fixed
/// across all levels (D-008, infinite progression / no win state); only speeds
/// and the frightened-window length change as the level climbs.
///
/// Speeds are expressed as *multipliers* applied to the actors' base
/// full-speed constants ([Pacman.speedTilesPerSec], [Ghost.normalSpeedTilesPerSec],
/// [Ghost.frightenedSpeedTilesPerSec]). The level-1 multipliers reproduce the
/// previous hard-coded feel; higher levels ramp toward 100%.
///
/// Plain Dart (no Flame) so it is trivially unit-testable per requirements §7.
class LevelTuning {
  const LevelTuning({
    required this.level,
    required this.playerSpeedMultiplier,
    required this.ghostSpeedMultiplier,
    required this.frightenedSpeedMultiplier,
    required this.frightenedSeconds,
  });

  /// The 1-based level this tuning describes.
  final int level;

  /// Player speed as a fraction of the base full speed (§8: L1 80%, L2-4 90%,
  /// L5+ 100%).
  final double playerSpeedMultiplier;

  /// Normal ghost (scatter/chase) speed fraction (§8: L1 75%, L2-4 85%, L5+ 95%).
  final double ghostSpeedMultiplier;

  /// Frightened ghost speed fraction (§8: L1 50%, L2-4 55%, L5+ 60%).
  final double frightenedSpeedMultiplier;

  /// Frightened-window length in seconds (§8: L1 6, L2 5, L3 4, L4 3, L5 2,
  /// L6-8 1, L9+ 0). A value of 0 means power pellets no longer frighten — the
  /// ghosts only reverse and the player still scores +50 (§8 / requirements).
  final double frightenedSeconds;

  /// Whether eating a power pellet starts a frightened window at this level.
  /// False from L9 on, where [frightenedSeconds] is 0.
  bool get hasFrightened => frightenedSeconds > 0;

  /// Resolve the tuning for a 1-based [level] from the §8 table. Levels are
  /// clamped to >= 1; the L5+ / L9+ bands extend to infinity (D-008).
  factory LevelTuning.forLevel(int level) {
    final l = level < 1 ? 1 : level;

    final double playerMul;
    final double ghostMul;
    final double frightenedMul;
    if (l == 1) {
      playerMul = 0.80;
      ghostMul = 0.75;
      frightenedMul = 0.50;
    } else if (l <= 4) {
      playerMul = 0.90;
      ghostMul = 0.85;
      frightenedMul = 0.55;
    } else {
      playerMul = 1.00;
      ghostMul = 0.95;
      frightenedMul = 0.60;
    }

    final double frightenedSeconds;
    if (l == 1) {
      frightenedSeconds = 6;
    } else if (l == 2) {
      frightenedSeconds = 5;
    } else if (l == 3) {
      frightenedSeconds = 4;
    } else if (l == 4) {
      frightenedSeconds = 3;
    } else if (l == 5) {
      frightenedSeconds = 2;
    } else if (l <= 8) {
      frightenedSeconds = 1;
    } else {
      frightenedSeconds = 0; // L9+: no frightened window (§8).
    }

    return LevelTuning(
      level: l,
      playerSpeedMultiplier: playerMul,
      ghostSpeedMultiplier: ghostMul,
      frightenedSpeedMultiplier: frightenedMul,
      frightenedSeconds: frightenedSeconds,
    );
  }
}
