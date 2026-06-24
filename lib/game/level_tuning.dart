/// Per-level difficulty tuning (requirements §8). Speeds and the
/// frightened-window length change as the level climbs (D-008, infinite
/// progression / no win state). The maze layout also cycles per level (D-008
/// revised), but that is owned by [Maze], not this table.
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

  /// Normal ghost (scatter/chase) speed fraction (§8: L1 75%, L2-4 85%,
  /// L5 95%). Past L5 it ramps a further +0.5%/level, capped at 105%, so
  /// infinite progression keeps tightening (D-008 revised).
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
      // L5+ band: the §8 table caps here at 100% / 95% / 60%. To keep infinite
      // progression from feeling flat (D-008 revised), ghosts keep edging up
      // very slowly past L5 — +0.5%/level above the 0.95 base — up to a hard
      // ceiling of 1.05 (reached around L25). The L5 value is exactly 0.95 so
      // the §8 band start is untouched; player/frightened multipliers stay at
      // the table values.
      playerMul = 1.00;
      const ghostBase = 0.95;
      const ghostCeil = 1.05;
      final ramped = ghostBase + (l - 5) * 0.005;
      ghostMul = ramped > ghostCeil ? ghostCeil : ramped;
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
