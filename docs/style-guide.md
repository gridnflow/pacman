# Style Guide — "Chompire" (working title)

Designer-owned visual identity, animation specs, and atlas formats for the Pac-Man-style
maze game (Flutter + Flame). All art is **original** — no trademarked names, sprites, or
exact character designs. Designed to read clearly at phone size and render cheaply at 60fps.

> Naming note: the player is the **Muncher** (a round chomper, not the trademarked
> character). Ghosts are the **Drifters**, each with its own name and silhouette.

---

## 1. Grid & atlas regime

Everything is built on a single base tile unit. This keeps the maze, sprites, and HUD
math trivial for the Developer.

| Constant | Value | Notes |
|---|---|---|
| **TILE** | **8 px** (source art) | The authoring grid. Maze cells, pellet spacing, sprite cells all derive from this. |
| **SPRITE** | **16 px** (2×2 tiles) | Player and ghosts occupy a 16×16 box but move on the 8px grid (center-anchored). |
| Render scale | integer multiple (×2, ×3…) | Flame scales the camera; never scale source art by non-integers — keep it crisp/pixel-perfect. |
| Maze playfield | 28 × 31 tiles | Classic proportion: 28 wide, 31 tall (3 rows reserved top/bottom for HUD). |
| Logical canvas | 224 × 248 px | 28×8 by 31×8. Camera fits this to screen width, letterboxing top/bottom. |

**Why 8px source:** classic arcade maze games author at 8px and render the actor at 16px.
It gives readable pixel art, tiny files, and clean grid collision. The Developer treats the
maze as a 28×31 char grid; movement is tile-to-tile at tile centers (per PROJECT_PLAN §3).

---

## 2. Color palette (hex)

A cool dark "neon arcade" identity — distinct from the trademarked black/blue/yellow look
while staying instantly legible.

### Core / maze
| Token | Hex | Use |
|---|---|---|
| `bg.deep` | `#0B0B1A` | Screen background (near-black indigo). |
| `bg.panel` | `#13132A` | HUD panel / pause overlay base. |
| `wall.fill` | `#1B2A6B` | Maze wall interior. |
| `wall.edge` | `#3B6BFF` | Maze wall stroke (neon blue, 1px). Glow read at distance. |
| `wall.edge.dim`| `#24388A` | Inner/secondary wall lines. |
| `gate` | `#FFB3D9` | Ghost-house gate bar (pink). |
| `path` | `#0B0B1A` | Walkable corridor = same as bg. |

### Pellets
| Token | Hex | Use |
|---|---|---|
| `pellet` | `#FFE9B0` | Normal pellet (warm cream). |
| `power` | `#FFD23F` | Power pellet (amber, blinks). |

### Player (Muncher)
| Token | Hex | Use |
|---|---|---|
| `muncher.body`| `#FFD23F` | Main yellow-gold body. |
| `muncher.shade`| `#E0A21E` | 1px lower-right shade for volume. |

### Ghosts (Drifters) — each a distinct hue + silhouette
| Drifter | Role (per requirements) | Body hex | Trim/eye-ring |
|---|---|---|---|
| **Ember** (red) | Direct chase (Blinky role) | `#FF4D4D` | `#FFFFFF` eyes |
| **Rosa** (pink) | Ambush 4-ahead (Pinky role) | `#FF8AD8` | `#FFFFFF` eyes |
| **Aqua** (cyan) | Inky role | `#4DE1FF` | `#FFFFFF` eyes |
| **Tango** (orange)| Clyde role | `#FFA94D` | `#FFFFFF` eyes |
| Eye iris (all) | — | `#2536C8` | Blue iris, looks toward move dir. |

### Ghost state colors
| State | Body | Detail |
|---|---|---|
| `frightened` | `#2536C8` | Deep blue body, pale face. |
| `frightened.flash`| `#FFFFFF` | White flash alt-frame when timer ending. |
| `frightened.mouth`| `#FF8AD8` | Pink wavy mouth + eyes. |
| `eaten` (eyes only)| `#FFFFFF` + `#2536C8` iris | Floating eyes returning to house. |

### UI text / accents
| Token | Hex | Use |
|---|---|---|
| `text.primary`| `#FFFFFF` | Score, labels. |
| `text.accent` | `#FFD23F` | Title, READY!, high score. |
| `text.muted` | `#8A8AB0` | Secondary labels. |
| `danger` | `#FF4D4D` | GAME OVER. |

**Silhouette rule (accessibility):** ghosts must differ by *shape of skirt waves + eye
position*, not just color, so colorblind players can still tell them apart. Ember = 3 sharp
spikes; Rosa = 4 round bumps; Aqua = 3 round bumps; Tango = 2 wide waves. Document this in
sprites so it survives the placeholder→final swap.

---

## 3. Player (Muncher) — sprite & chomp animation

**Sprite box:** 16×16. Center-anchored on the 8px grid.

**Design direction:** a round gold disc with a wedge mouth. Slight 1px darker rim on the
lower-right for a subtle 3D pop. No face/eyes (keeps it original and clean). Mouth opens
toward the direction of travel.

**Chomp cycle:** 3 frames, ping-pong, looped while moving.
| Frame | Mouth | Hold |
|---|---|---|
| C0 | closed (full circle) | 1 unit |
| C1 | half-open wedge (~45°) | 1 unit |
| C2 | wide-open wedge (~90°) | 1 unit |
Sequence played `C0 → C1 → C2 → C1 →` (ping-pong) at **stepTime 0.07 s** (~14 fps), so a
full open-close ≈ 0.28 s. **Pause on C0 (closed)** when the player is not moving.

**Direction:** Do NOT bake 4 directional rows. Author the chomp facing **right** only;
the Developer rotates the component by direction (0°/90°/180°/270°). This keeps the sheet
tiny. (Mark this clearly for the loader.)

**Death animation:** 11 frames, play once, ~0.10 s/frame (≈1.1 s total). The disc's mouth
opens progressively wider until the wedge swallows the whole body, then it collapses to a
thin line and vanishes (last frame fully transparent). After it finishes, the Developer
respawns or shows GAME OVER. Death frames are authored facing up.

---

## 4. Ghosts (Drifters) — sprite & animation

**Sprite box:** 16×16. Classic "dome + wavy skirt" body, two eyes that look toward the
current move direction.

**Movement (normal) animation:** 2 frames, looped, **stepTime 0.16 s** — the skirt waves
swap (wave crests shift by half a wave) to read as gliding. This is shared across all four
Drifters; only the body color and skirt-wave shape change.

**Eyes / direction:** 4 eye positions (look up/down/left/right). Author as **one body** +
**4 eye overlays**, OR bake 4 eye variants per move frame. To keep the loader simple we
bake it: each Drifter row = `[mv0-right, mv1-right, mv0-up, mv1-up, mv0-down, mv1-down,
mv0-left, mv1-left]` = 8 cells. (See atlas §7.)

**Frightened:** 2 frames, looped, stepTime 0.16 s. Deep-blue body, pink wavy mouth + small
pale eyes, no directional eyes (same art all directions). When the frightened timer is in
its **final ~2 s**, alternate frightened-blue ↔ white-flash at stepTime 0.20 s as the
classic "about to wear off" cue.

**Eaten (eyes only):** the body disappears; only a pair of eyes remains, looking toward the
direction the eyes are travelling back to the house. 4 cells (one per direction), no
per-frame animation. Drawn at full brightness so they read on the dark maze.

---

## 5. Pellets & power pellets

- **Pellet:** 2×2 px dot, `pellet` color, centered in an 8px tile. Authored as a single
  static sprite in an 8×8 cell (dot centered). Static, no animation.
- **Power pellet:** ~6 px circle, `power` color, centered in an 8px cell (bleeds slightly,
  that's fine). **Blink animation:** 2 frames (on/off) at stepTime **0.20 s** — a simple
  visibility toggle the Developer can also do in code, but provide both frames so it works
  via the animation path. Optional 1px soft glow ring on the "on" frame.

---

## 6. Typography

- **Primary font:** a free, license-clean pixel/arcade font — **"Press Start 2P"**
  (SIL Open Font License, redistributable). Bundle at `assets/fonts/PressStart2P-Regular.ttf`.
  All HUD numerals, READY!, GAME OVER, menu labels.
- **Fallback:** Flutter default (`Roboto`) only for any long-form text (there is none in v1).
- Sizes (logical px, before camera scale): Title 16, HUD labels 8, score 8, big overlay
  ("GAME OVER", "READY!") 16. Always integer sizes to stay pixel-crisp.
- Letter-spacing 1px; never anti-alias the pixel font (disable font smoothing where Flame
  allows; render at integer scale).

---

## 7. Sprite-sheet / tile-atlas specs (for the loader)

All atlases are **PNG, RGBA, no padding, no premultiplied weirdness, origin top-left,
left-to-right then top-to-bottom**. Cell sizes are exact; no trim. Transparent background.

### 7.1 `assets/tiles/maze_atlas.png` — maze tiles
- **Cell:** 8×8 px. Sheet: 8 columns × 4 rows = 64×32 px.
- Cell index → tile (the Developer maps the maze char grid to these):

| Idx | Tile |
|---|---|
| 0 | empty / path |
| 1 | wall straight horizontal |
| 2 | wall straight vertical |
| 3 | wall corner ┌ |
| 4 | wall corner ┐ |
| 5 | wall corner └ |
| 6 | wall corner ┘ |
| 7 | wall T / junction |
| 8 | ghost-gate bar |
| 9 | tunnel edge (left) |
| 10 | tunnel edge (right) |
| 11–31 | reserved (double-line variants, house walls) |

> Walls may also be drawn procedurally (rounded-rect strokes in `wall.edge` over
> `wall.fill`) instead of from tiles. The atlas is the fallback / placeholder path; the
> Developer chooses. Either way the **palette and 8px grid are fixed**.

### 7.2 `assets/sprites/muncher.png` — player
- **Cell:** 16×16 px. Layout: **1 row × 14 cells** = 224×16 px.
- Cells 0–2: chomp `C0,C1,C2` (facing right).
- Cells 3–13: death frames `D0…D10` (11 frames, facing up).

### 7.3 `assets/sprites/ghosts.png` — all four Drifters + shared states
- **Cell:** 16×16 px. Layout: **6 rows × 8 cols** = 128×96 px.
- Row 0 = Ember, Row 1 = Rosa, Row 2 = Aqua, Row 3 = Tango. Each row, 8 cells:
  `[mv0-R, mv1-R, mv0-U, mv1-U, mv0-D, mv1-D, mv0-L, mv1-L]`.
- Row 4 = **frightened** (shared): cells 0–1 = blue frames, cells 2–3 = white-flash
  frames, cells 4–7 unused (transparent).
- Row 5 = **eaten eyes** (shared): cells 0–3 = eyes facing `R,U,D,L`, cells 4–7 unused.

### 7.4 `assets/sprites/pellets.png` — pellets
- **Cell:** 8×8 px. Layout: 1 row × 4 cells = 32×8 px.
- Cell 0: pellet. Cell 1: power pellet ON. Cell 2: power pellet OFF (empty/transparent).
  Cell 3: bonus-fruit icon (single original "berry" glyph, `#FF4D4D` + `#3BC46B` leaf).

### 7.5 Summary table for the Developer's loader

| File | Cell px | Cols×Rows | Sheet px | Anim stepTime |
|---|---|---|---|---|
| `tiles/maze_atlas.png` | 8 | 8×4 | 64×32 | static |
| `sprites/muncher.png` | 16 | 14×1 | 224×16 | chomp 0.07 / death 0.10 |
| `sprites/ghosts.png` | 16 | 8×6 | 128×96 | move 0.16 / fright 0.16 (flash 0.20) |
| `sprites/pellets.png` | 8 | 4×1 | 32×8 | power blink 0.20 |

---

## 8. UI screen layouts

Logical canvas 224×248 (portrait). All overlays use `bg.panel` at 85% alpha over the maze.

### 8.1 Start screen
```
┌────────────────────────────┐
│                            │
│         C H O M P          │   ← Title, text.accent, size 16, gold, with a
│         P I R E            │     small Muncher chomping next to it (idle loop)
│                            │
│      ◀ TAP TO PLAY ▶       │   ← pulsing, text.primary, size 8
│                            │
│   HIGH  010000             │   ← text.muted label + accent number
│                            │
│   ● ● ●   the four Drifters │   ← row of 4 ghost sprites drifting across
│                            │
│        SOUND  [ON]         │   ← toggle, bottom
└────────────────────────────┘
```

### 8.2 HUD (in-game)
- **Top bar (y 0–16):** `SCORE 000000` left (size 8), `HIGH 010000` center, level dot
  count optional right.
- **Maze (y 16–232):** the 28×31 playfield.
- **Bottom bar (y 232–248):** lives as up-to-3 mini Muncher icons (16×16 scaled to 12)
  left; current **level fruit icons** right (shows up to 7 recent fruits).
- HUD never overlaps walkable maze; it lives in the reserved top/bottom rows.

### 8.3 Pause overlay
```
┌────────────────────────────┐
│        ▌ ▌  PAUSED         │   ← centered, size 16, text.accent
│                            │
│        ▶  RESUME           │   ← size 8 buttons, stacked, 44px touch targets
│        ↻  RESTART          │
│        ⌂  QUIT             │
│        SOUND  [ON]         │
└────────────────────────────┘
```
Triggered by a pause button in the top-right corner of the HUD (44×44 logical touch area).

### 8.4 Game-over overlay
```
┌────────────────────────────┐
│       G A M E  O V E R      │   ← danger red, size 16
│                            │
│       SCORE   012340       │   ← text.primary
│       BEST    012340  NEW! │   ← "NEW!" in accent if high score beaten
│                            │
│        ▶  PLAY AGAIN       │   ← primary button, 44px target
│        ⌂  MENU             │
└────────────────────────────┘
```

### 8.5 READY! / level-intro
Centered `READY!` in `text.accent` size 16 over the freshly drawn maze for ~2 s before the
player and ghosts start moving (classic round-start beat). Reuse for each new level.

---

## 9. Game-feel notes (juice)

- **Pellet eat:** tiny scale-pop (no sound spam — alternate two short "wakka" tones).
- **Power pellet:** brief 0.1 s full-screen subtle flash (`power` at 8% alpha), maze
  wall-edge color pulse once.
- **Ghost eaten:** freeze action ~0.4 s and show the chain score popup (200/400/800/1600)
  in `text.primary` at the ghost's tile, then resume.
- **Death:** stop maze, dim walls to `wall.edge.dim`, play the 11-frame death anim.
- **Level clear:** flash the maze wall-edge `wall.edge` ↔ `#FFFFFF` 4× over ~1 s, then load
  next level.
- Keep all juice cheap: alpha flashes and scale tweens only — no shaders, no per-frame
  allocation, to protect 60fps on low-end phones.

(Detailed control + feedback/sound spec in `docs/control-scheme.md`.)
