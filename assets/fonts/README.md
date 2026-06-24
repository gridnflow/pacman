# Fonts

**Status (Phase 6):** no real font bundled yet.

`PressStart2P-Regular.ttf` (OFL, redistributable — decision D-020) belongs here, but
it could not be fetched in the offline build environment. Until it is added:

- Text **falls back to the system default font** (must not crash).
- The `fonts:` block in `pubspec.yaml` stays **commented out** (decision D-023).

To finalize: drop `PressStart2P-Regular.ttf` in this directory and uncomment the
`fonts:` block in `pubspec.yaml`. No other code changes needed if the family name
stays `PressStart2P`.
