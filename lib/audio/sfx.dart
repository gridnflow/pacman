import 'package:flame_audio/flame_audio.dart';

/// Sound-effects facade (control-scheme §4.1). All cues are short, low-latency,
/// and mutable via a persisted toggle.
///
/// Phase 6 (Polish): wired to `flame_audio`. The SFX bank lives in
/// `assets/audio/*.wav` (silent placeholder stubs for now, decision D-021/D-022).
/// Every entry point is defensive: a failed preload or a playback error (e.g. in
/// a headless test environment with no audio backend) is swallowed so the game
/// loop never crashes on a missing/unsupported clip.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  bool muted = false;

  /// Set once [preload] succeeds. While false every cue is a no-op, so calling
  /// a sound before assets are ready (or in a test without an audio backend) is
  /// harmless.
  bool _ready = false;

  /// The looping frightened-siren player, kept so it can be stopped on expiry.
  AudioPlayer? _siren;

  /// True while a siren-stop was requested before the loop finished starting.
  bool _sirenStopPending = false;

  /// Toggles between the two "wakka" tones on successive pellets (§4.1).
  bool _chompToggle = false;

  // --- File names (relative to the `assets/audio/` cache prefix) ---
  static const String _chompA = 'chomp_a.wav';
  static const String _chompB = 'chomp_b.wav';
  static const String _power = 'power.wav';
  static const String _sirenFile = 'siren.wav';
  static const String _ghostEat = 'ghost_eat.wav';
  static const String _extraLife = 'extra_life.wav';
  static const String _death = 'death.wav';
  static const String _levelClear = 'level_clear.wav';
  static const String _fruit = 'fruit.wav';
  static const String _uiTap = 'ui_tap.wav';
  static const String _readyCue = 'ready.wav';

  static const List<String> _bank = [
    _chompA, _chompB, _power, _sirenFile, _ghostEat, _extraLife,
    _death, _levelClear, _fruit, _uiTap, _readyCue,
  ];

  /// Preload the small SFX bank into the Flame audio cache. Safe to call more
  /// than once; failures (no audio backend, missing files) are swallowed and
  /// leave the facade in its silent no-op state.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll(_bank);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Fire-and-forget one-shot. Never throws; swallows any playback failure.
  void _play(String file, {double volume = 1.0}) {
    if (muted || !_ready) return;
    // Errors from the platform player are non-fatal (e.g. headless test host).
    FlameAudio.play(file, volume: volume).then((_) {}, onError: (_) {});
  }

  void roundStart() => _play(_readyCue);

  void pellet() {
    // Alternating two-tone "wakka" (§4.1).
    _chompToggle = !_chompToggle;
    _play(_chompToggle ? _chompA : _chompB, volume: 0.6);
  }

  void powerPellet() {
    _play(_power);
    _startSiren();
  }

  void ghostEaten() => _play(_ghostEat);
  void extraLife() => _play(_extraLife);

  void death() {
    _stopSiren();
    _play(_death);
  }

  void levelClear() {
    _stopSiren();
    _play(_levelClear);
  }

  void fruit() => _play(_fruit);
  void uiTap() => _play(_uiTap, volume: 0.7);

  /// Start the looping frightened siren if it is not already running.
  void _startSiren() {
    if (muted || !_ready || _siren != null) return;
    _sirenStopPending = false;
    FlameAudio.loop(_sirenFile, volume: 0.4).then((p) {
      if (_sirenStopPending) {
        // Window ended while the loop was still starting — stop immediately.
        _sirenStopPending = false;
        p.stop().catchError((_) {});
      } else {
        _siren = p;
      }
    }).catchError((_) {});
  }

  /// Stop the frightened siren loop (frightened window ended / death / clear).
  void stopSiren() => _stopSiren();

  void _stopSiren() {
    final p = _siren;
    _siren = null;
    if (p == null) {
      // Loop may still be starting; flag it so it stops on arrival.
      _sirenStopPending = true;
      return;
    }
    p.stop().catchError((_) {});
  }

  void stopAll() {
    _stopSiren();
    if (!_ready) return;
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }
}
