# Decision Log

Cross-team decisions for the maze-chase game. The Requirements Engineer owns this log;
Designer and Developer must log any spec-affecting decision here so the three stay in
sync. Newest-relevant decisions stay near the top of their section.

Format: **Date | Decision | Rationale | Affected agent(s)**

| Date       | Decision | Rationale | Affected agent(s) |
|------------|----------|-----------|-------------------|
| 2026-06-23 | **D-001 Trademark avoidance.** No user-facing use of the classic title, ghost names, or original art; reference mechanics only. Internal code may use Blinky/Pinky/Inky/Clyde as identifiers. | Legal safety; brief mandates mechanics-only, original assets only. | Designer (all art/strings original), Developer (no trademarked strings in UI/store listing), Requirements |
| 2026-06-23 | **D-002 Engine = Flutter + Flame.** Single Dart codebase → iOS + Android; Flame provides game loop, component tree, collisions, tilemaps. | Right-sized 2D engine; one language for the team; matches PROJECT_PLAN §1. | Developer (primary), Designer (asset formats Flame expects) |
| 2026-06-23 | **D-003 Single canonical maze, 28×31, TILE_SIZE=8.** One fixed tilemap checked into repo; identical every level. | Classic playfield dimensions; keeps scope tight; deterministic tests. | Developer (loader/render), Designer (tile atlas to 8px grid), Requirements |
| 2026-06-23 | **D-004 Preserve Pinky/Inky UP-direction overflow bug.** When the player faces UP, the "ahead" pivot shifts up AND left. | Faithful feel; the bug shapes ambush patterns players expect. | Developer (implement exactly + unit test), Requirements |
| 2026-06-23 | **D-005 Frightened re-trigger resets timer AND eat-chain to 200.** Eating a 2nd power pellet during a frightened window restarts the full duration and resets the chain to 200. | Removes ambiguity for the Developer; predictable scoring. | Developer, Requirements |
| 2026-06-23 | **D-006 Ghost-house release: per-ghost dot counter for v1.** Inky after 30 dots, Clyde after 60 (level 1); simplified vs. the classic global counter. The exact global counter is optional; if the simple version ships, that's accepted. | Big complexity reduction with minor fidelity cost; deviation pre-approved. | Developer (implement simple counter, note if global is skipped), Requirements |
| 2026-06-23 | **D-007 Extra life: one-time at 10,000 points.** No repeating bonus lives. | Simpler, testable; classic awards one bonus life by default. | Developer, Requirements |
| 2026-06-23 | **D-008 No final win state.** Levels continue indefinitely; difficulty caps at the level-5+ band; goal is high score. | Endless arcade loop; avoids an arbitrary "you win" screen. | Developer, Designer (no win screen needed), Requirements |
| 2026-06-23 | **D-009 Level 9+ power pellets do not make ghosts edible.** Power pellet still scores 50 and forces one reversal, but frightened time = 0. | Faithful difficulty ramp; explicit so it isn't read as a bug. | Developer, Designer (no frightened art shown at those levels), Requirements |
| 2026-06-23 | **D-010 Elroy (Blinky speedup) optional for v1.** If omitted, Blinky uses table ghost speed throughout; must be logged here when cut. | De-risks the schedule; nice-to-have fidelity, not core. | Developer (decide & log), Requirements |
| 2026-06-23 | **D-011 Deterministic frightened movement via seeded PRNG.** Frightened ghosts turn pseudo-randomly from a logged seed so tests are reproducible. | Enables unit/replay tests of frightened behavior (NFR-06). | Developer (seed + expose for tests), Requirements |
| 2026-06-23 | **D-012 Deterministic tie-break UP>LEFT>DOWN>RIGHT.** Ghost turn decisions break distance ties in this fixed order. | Reproduces classic determinism; makes targeting unit-testable. | Developer, Requirements |
| 2026-06-23 | **D-013 Targets OS: Android 8.0 (API 26)+ / iOS 13+; portrait; ≤60 MB; offline-only.** | Reasonable 2026 floor covering most devices; matches NFR-02/03/04. | Developer (build config), Designer (portrait layouts), Requirements |
| 2026-06-23 | **D-014 Persistence via on-device key-value store (e.g. shared_preferences).** High score + audio toggle only; nothing leaves the device. | Satisfies offline-only; minimal footprint. | Developer, Requirements |
| 2026-06-23 | **D-015 Bonus fruit appears at 70 and 170 pellets, ~9.5 s each.** | Concrete, testable timing derived from classic behavior. | Developer, Designer (fruit art + popup), Requirements |
| 2026-06-23 | **D-016 Control scheme = full-screen swipe (buffered); optional D-pad off by default (resolves OQ-1).** Swipe min travel 16 logical px, axis dominance ≥1.3×, buffer window 0.5 s, instant reversal, 44×44 min touch targets. Same `queuedDirection` event feeds both swipe and the optional D-pad. | Frees the small screen for the maze; grid+buffered movement maps naturally to a flick; D-pad's continuous-hold affordance is wasted here. See `docs/control-scheme.md`. | Developer (input layer behind one interface), Requirements (ratify into S-01) |
| 2026-06-23 | **D-017 Asset atlas regime fixed (Designer).** Source art authored at 8px tile; actors 16×16. Files & layouts: `tiles/maze_atlas.png` 64×32 (8×8 cells, 8×4); `sprites/muncher.png` 224×16 (16×16, 14×1: chomp C0–2 facing right + death D0–10 facing up); `sprites/ghosts.png` 128×96 (16×16, 8×6: rows 0–3 = the 4 Drifters with 8 cells `mvR,mvU,mvD,mvL`×2 frames, row 4 = frightened, row 5 = eaten eyes); `sprites/pellets.png` 32×8 (8×8, 4×1: pellet/power-on/power-off/fruit). Player chomp is single-direction art rotated in code. | Tight, phone-readable, cheap to render (60fps); single 8px grid keeps loader math trivial; integer-scale only. See `docs/style-guide.md` §7 and `assets/PLACEHOLDER.md`. | Developer (loader matches these exactly), Requirements |
| 2026-06-23 | **D-018 Animation timings (Designer).** Chomp 3-frame ping-pong @0.07 s (closed when idle); ghost move 2-frame @0.16 s; frightened 2-frame @0.16 s, white-flash @0.20 s in final ~2 s; eaten eyes static per direction; player death 11-frame once @0.10 s; power-pellet blink @0.20 s. | Concrete, testable frame counts/timings the Developer wires into Flame animations. | Developer, Requirements |
| 2026-06-23 | **D-019 Design-side handling of D-009 (level 9+ no-frightened).** At those levels the Developer skips the frightened/flash animation rows and keeps ghosts in normal-move art (power pellet still scores 50 + forces reversal). No extra art needed. | Confirms D-009 needs no special Designer asset. | Designer, Developer |
| 2026-06-23 | **D-020 Font = Press Start 2P (OFL).** Bundled at `assets/fonts/PressStart2P-Regular.ttf`; integer sizes, no anti-aliasing. All HUD/menu text. | License-clean redistributable pixel font; original, no trademarked typeface. | Developer (pubspec + theme), Designer |

## Open questions (need a decision before/at build time)
- **OQ-1 Control scheme:** ~~swipe vs. on-screen D-pad vs. both.~~ **RESOLVED by D-016**
  — full-screen buffered swipe, optional D-pad off by default. Awaiting Requirements
  ratification into S-01.
- **OQ-2 Exact scatter-corner tiles** and **no-up tile set**: to be fixed by the
  canonical tilemap once Designer/Developer commit the map. → Developer + Requirements.
- **OQ-3 Whether to ship Elroy (D-010) and the global house counter (D-006)** for v1.
  → Developer call during P1/P2.
