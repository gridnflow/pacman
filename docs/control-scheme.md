# Control Scheme & Feedback Spec

Designer-owned touch control, HUD interaction, and feedback (sound + score popups) spec.
Targets small phones and 60fps. Pairs with `docs/style-guide.md`.

---

## 1. Decision: **Swipe** (full-screen gesture), not an on-screen D-pad

**Chosen scheme: directional swipe anywhere on the maze area, with input buffering.**

### Rationale
| Factor | Swipe | On-screen D-pad |
|---|---|---|
| Screen real estate | Frees the whole screen for the maze (small phones). | Eats a corner; thumb covers part of maze. |
| Fits grid movement | Maze movement is 4-directional and *buffered* — you flick the next turn ahead of the corridor. Swipe maps perfectly: one flick = one queued direction. | Works, but holding a pad implies continuous control the game doesn't need. |
| Thumb fatigue | Light, occasional flicks. | Constant thumb contact. |
| Occlusion | None over the maze. | D-pad + thumb occludes ~15% of a small screen. |
| Precision risk | Diagonal/short swipes can misread → mitigations below. | Very precise. |

Pac-Man-style movement is *grid-locked with a one-step input buffer* (PROJECT_PLAN §3):
the player only needs to express "turn this way at the next junction," which a flick
expresses naturally. A D-pad's continuous-hold affordance is wasted here. So swipe wins on
small touch screens.

**Accessibility / fallback:** ship an **optional D-pad** toggle in Settings (off by
default). Same input events feed the buffer, so the Developer implements both behind one
`Direction queued` interface. Spec for the optional pad is in §5.

---

## 2. Swipe behavior (the spec the Developer implements)

- **Recognition:** a pan gesture over the maze region. On pan end (or on crossing a
  threshold mid-pan), compute dominant axis from `(dx, dy)`:
  - `|dx| >= |dy|` → horizontal: `dx>0` Right, else Left.
  - else → vertical: `dy>0` Down, else Up.
- **Threshold:** minimum travel **16 logical px** (≈ 2 tiles of source, comfortably above
  jitter). Below threshold = ignored (treat as a tap, not a move).
- **Early commit:** fire the direction as soon as travel crosses the threshold *and* one
  axis dominates by ≥ 1.3×, without waiting for finger lift. This makes turns feel instant.
  Debounce so one continuous swipe emits at most one direction (reset on pan end).
- **Buffering:** the emitted direction is stored as `queuedDirection`. The player applies
  it at the **next valid tile center** where that direction is not a wall (per the grid
  rules). A queued turn persists ~0.5 s (or until consumed/overwritten) so a slightly-early
  flick still lands the turn. The most recent valid swipe overwrites the queue.
- **Reverse is instant:** a swipe directly opposite the current heading applies immediately
  (no junction needed) — feels responsive in corridors.
- **No movement when paused / on overlays.** Swipes are captured only over the maze region
  (HUD bars and overlays consume their own taps).

**Why these numbers:** 16px threshold + 1.3× dominance kills accidental diagonal misfires
on small screens while keeping flicks fast. Buffer window 0.5s matches the classic
"pre-turn" feel without letting stale inputs fire.

---

## 3. HUD layout & touch targets

Logical canvas 224×248 (see style-guide §8.2). Interactive elements only outside the maze.

```
┌──────────────────────────────────────┐  y0
│ SCORE 000000   HIGH 010000      [ ‖ ] │  ← top bar (16px). [‖]=pause, 44×44 touch
├──────────────────────────────────────┤  y16
│                                        │
│              M A Z E                   │  ← swipe surface (224×216)
│            (28×31 tiles)               │
│                                        │
├──────────────────────────────────────┤  y232
│ ◔ ◔ ◔   lives          🍓🍒  fruit     │  ← bottom bar (16px), non-interactive
└──────────────────────────────────────┘  y248
```

- **Pause button:** top-right, **44×44 logical px** hit area (Apple HIG / Material min),
  even though the glyph is small. Tapping opens the pause overlay (style-guide §8.3).
- **Overlay buttons** (pause/game-over/start): stacked, each min **44 px tall**, full-ish
  width with 8px gaps, large text size 8–16. Generous targets for thumbs.
- **Lives / fruit:** display-only.
- Safe areas: respect device notch/home-indicator insets — letterbox the canvas inside
  `SafeArea`; never place the pause button or buttons under a notch.

---

## 4. Feedback

### 4.1 Sound cues (Developer wires via Flame audio; Designer specifies the events)
Keep the bank tiny and loopable. All SFX short, punchy, low-latency; mixable without
clipping. Provide an in-game **mute toggle** (start + pause screens); persist the setting.

| Event | Cue | Notes |
|---|---|---|
| Round start (READY!) | short rising 3-note jingle (~1.2 s) | Blocks movement until done. |
| Pellet eat | two-tone "wakka" alternating A/B per pellet | Rapid; do not overlap-spam — retrigger, don't stack. |
| Power pellet eat | low "wub" + start frightened siren loop | Siren loops only while any ghost frightened. |
| Ghost eaten | rising "blip-up" sweep | Pairs with the 0.4 s freeze + score popup. |
| Extra life | bright chime | At the score threshold (per requirements). |
| Player death | descending "down" warble (~1.1 s) | Synced to the 11-frame death anim. |
| Level clear | short victory arpeggio (~1 s) | Over the maze flash. |
| Fruit eat | sparkle ping | Bonus fruit pickup. |
| Ambient | siren whose pitch rises as pellets deplete (optional, classic tension) | Cheap; off if perf-constrained. |
| UI tap | soft click | Buttons/toggles. |

Asset hand-off: list these as `assets/audio/*.ogg` (small, looped where noted). Final SFX
in polish phase; the Developer can stub silent clips first.

### 4.2 Score popups (screen juice)
- **Ghost eat chain:** show `200 / 400 / 800 / 1600` as floating text at the eaten ghost's
  tile, `text.primary`, size 8, during the 0.4 s action freeze, then fade up + out over
  0.5 s. Resets to 200 each new power-pellet window.
- **Fruit:** show the fruit's point value (e.g. `100`) at its tile, `text.accent`, fade
  out 0.6 s.
- **Extra life:** brief `1UP` flash in `text.accent` near the lives row.
- Popups are non-interactive, never block input, and are pooled/reused to avoid per-frame
  allocation (60fps rule).

### 4.3 Haptics (optional, cheap)
- Light impact on: ghost eaten, power-pellet eaten, player death (medium). Respect a
  Settings toggle and the OS "reduce haptics" preference. Off if it costs frames.

---

## 5. Optional D-pad (accessibility fallback spec)

Enabled via Settings. When on:
- Render a 4-way pad bottom-left, ~64×64 logical px, semi-transparent (`text.primary` at
  30%), 12px inset from the safe-area edge.
- Tapping/holding a direction emits the same `queuedDirection` event as a swipe (same
  buffering rules in §2). Hold = keep re-queuing that direction.
- Pad sits over a non-walkable HUD margin where possible; if it must overlap the maze, keep
  it at low alpha and bottom-left where the maze corridor density is lowest.

---

## 6. Quick reference for the Developer

| Param | Value |
|---|---|
| Primary control | Full-screen swipe over maze, buffered |
| Swipe min travel | 16 logical px |
| Axis dominance | ≥ 1.3× |
| Buffer window | 0.5 s (overwrite with newest) |
| Reverse direction | instant (no junction) |
| Min touch target | 44 × 44 logical px |
| Mute toggle | start + pause, persisted |
| D-pad | optional, off by default, same event interface |
