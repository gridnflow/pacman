/// Sound-effects facade (control-scheme §4.1). All cues are short, low-latency,
/// and mutable via a persisted toggle.
///
/// Phase 1 (Skeleton): a no-op stub with the event surface defined. Wiring to
/// Flame audio + bundling `assets/audio/*.ogg` is a Phase 6 TODO. The Developer
/// can stub silent clips first.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  bool muted = false;

  /// TODO(Phase 6): preload the small SFX bank via FlameAudio.audioCache.
  Future<void> preload() async {}

  void roundStart() {}
  void pellet() {} // alternating two-tone "wakka"
  void powerPellet() {} // "wub" + start frightened siren loop
  void ghostEaten() {}
  void extraLife() {}
  void death() {}
  void levelClear() {}
  void fruit() {}
  void uiTap() {}

  void stopAll() {}
}
