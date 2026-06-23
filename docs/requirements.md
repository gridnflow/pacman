# Requirements — Maze Chase (working title)

**Owner:** Requirements Engineer · **Status:** v1 baseline · **Last updated:** 2026-06-23

This is the source of truth for game rules. Every rule here is intended to be verifiable
by an automated test or a deterministic manual check. The Developer implements these
exactly; on any ambiguity, the spec is updated here rather than guessed at.

> **Trademark note:** This game references the *mechanics* of the classic 1980 arcade
> maze-chase game only. We do not use the trademarked title, character names as
> player-facing strings, or any original art. Internal code/identifiers may use the
> classic ghost nicknames (Blinky/Pinky/Inky/Clyde) for clarity, but no user-facing
> string, asset, or store listing may use them. See `docs/decisions.md` (D-001).

---

## 0. Terminology & coordinate system

- **Tile.** The maze is a grid of square tiles. A tile is the atomic unit of position.
- **Tile coordinate** `(col, row)` — integers. `col` increases rightward (x), `row`
  increases downward (y). `(0,0)` is the top-left tile.
- **Pixel position.** `pixel = tile * TILE_SIZE + TILE_SIZE/2` gives a tile's center.
- **Actor.** The player or a ghost. Actors occupy a continuous pixel position but their
  *tile* is `floor(pixel / TILE_SIZE)`.
- **Tile center.** The point where turns/decisions happen.
- **Direction.** One of `UP, DOWN, LEFT, RIGHT` (no diagonals). As vectors:
  `UP = (0,-1)`, `DOWN = (0,+1)`, `LEFT = (-1,0)`, `RIGHT = (+1,0)`.
- **Distance (for targeting).** Squared Euclidean distance between two tiles:
  `dist²((ax,ay),(bx,by)) = (ax-bx)² + (ay-by)²`. Squared is sufficient and avoids
  floating point; ghosts compare distances, never use the actual magnitude.

---

## 1. The maze

### 1.1 Grid
- **Grid size:** `28 columns × 31 rows` of tiles (the classic playfield), excluding the
  HUD rows rendered above/below the maze.
- **TILE_SIZE:** 8 logical pixels per tile in the maze model. Rendering scales this to
  the device; see §11.
- **Tile types** (each tile is exactly one type):
  - `WALL` — impassable to all actors.
  - `PATH` — walkable; may contain a pellet.
  - `TUNNEL` — walkable; the two horizontal tunnel exits on the middle row wrap.
  - `HOUSE` — the ghost house interior (where ghosts start / respawn).
  - `HOUSE_DOOR` — the single-tile-wide door; only ghosts pass, and only when
    leaving/entering the house. The player can never enter `HOUSE`/`HOUSE_DOOR`.
  - `GATE_PATH` — the row directly above the house door; walkable by the player but
    **no pellet** is placed there, and ghosts may not turn `UP` here (see §4.6).

### 1.2 Tunnel wrap
- There is one horizontal tunnel on the maze's middle corridor row.
- When an actor's center crosses the left edge of the leftmost tunnel tile moving
  `LEFT`, it reappears at the rightmost tunnel tile (and symmetrically for `RIGHT`).
- **Acceptance:** an actor entering the left tunnel exit moving LEFT exits from the
  right tunnel exit on the same row, preserving direction and sub-tile offset.

### 1.3 Ghost house
- The house is a `HOUSE` chamber, interior roughly `7×3` tiles, centered horizontally,
  in the lower-middle of the maze, with a one-tile `HOUSE_DOOR` on its top edge.
- Start positions: Blinky starts **just outside/above** the door on `GATE_PATH`; Pinky,
  Inky, and Clyde start **inside** the house (Pinky center, Inky left, Clyde right).

### 1.4 Static layout requirement
- The maze layout is **fixed and identical every level** (only actor speeds, pellet
  respawn, and timings change between levels). It is defined by a single canonical
  ASCII/`int` tilemap checked into the repo as the authoritative source.
- **Acceptance:** loading the tilemap yields exactly 28×31 tiles; wall tiles form a
  fully enclosed boundary except at the two tunnel exits; the maze is symmetric across
  its vertical center line except for pellet edge-cases that the map explicitly encodes.

---

## 2. Pellets & power pellets

### 2.1 Counts and placement
- **Pellets (dots):** exactly **240** standard pellets. One pellet per eligible `PATH`
  tile. A `PATH` tile is *pellet-eligible* unless it is: inside/under the ghost house
  region, on the tunnel tiles, on `GATE_PATH`, or on an actor start tile that the map
  marks as empty.
- **Power pellets (energizers):** exactly **4**, one near each of the four maze corners
  (the classic positions: cols 1 and 26, rows 3 and 23, approximately — exact tiles come
  from the canonical map).
- **Total edible pellets at level start:** `240 + 4 = 244`.
- A power pellet tile does **not** also hold a standard pellet.

### 2.2 Eating
- A pellet/power pellet is eaten when the **player's tile equals the pellet's tile**
  (center-overlap is not required; tile occupancy is).
- Each tile holds at most one pellet; eating removes it for the remainder of the level.

### 2.3 Acceptance
- Counting eligible pellet tiles in the canonical map returns exactly 240 standard + 4
  power.
- Eating the 244th pellet triggers the level-clear sequence (§7).
- A pellet cannot be eaten twice; the level pellet counter is monotonic non-increasing.

---

## 3. The player

### 3.1 Movement
- **Grid-locked, continuous speed.** The player moves continuously along the current
  direction at the level's player speed (§8). Turns occur only at tile centers.
- **Buffered input.** The most recent directional input is stored as `desiredDir`. At
  (or within a small tolerance before) a tile center, if moving in `desiredDir` is not
  blocked by a `WALL`/door, the player adopts `desiredDir` as `currentDir`. Otherwise it
  keeps `currentDir`.
  - **Pre-turn / corner-cut tolerance:** a queued turn may be applied up to `2 px` before
    the exact center to make cornering feel responsive. It must never let the player pass
    through a wall.
- **Reversal** is always allowed immediately (180° flip) even between tile centers,
  because the opposite direction is never wall-blocked if the current one isn't.
- **Wall stop.** If the player reaches a tile center and `currentDir` is blocked and no
  valid `desiredDir` is queued, the player stops at the center until a valid input.

### 3.2 Acceptance
- Pressing UP while moving LEFT in a corridor with an opening above causes the turn to
  happen exactly at the next tile center (± tolerance), not mid-tile.
- Holding into a wall stops the player flush at the tile center; no jitter, no overlap.
- A buffered direction set 1–2 tiles early is honored at the first legal tile.

---

## 4. Ghosts

There are four ghosts. All share one finite-state machine (§5) but differ only in their
**target tile** function while in `CHASE`, and in their fixed `SCATTER` corner.

### 4.0 Common ghost movement rules
- Ghosts move tile-to-tile at their level speed (§8); they choose a direction **only at
  tile centers**.
- **No stopping, no reversing at will.** A ghost never stops and never reverses
  direction on its own. The only forced reversal is the global event when the mode
  switches between scatter/chase or when frightened begins/ends (§5.4).
- **Turn decision (deterministic):** at each tile center, consider the available exits =
  all neighboring tiles that are not `WALL` and not the tile directly behind (i.e.
  excluding a 180° reversal). Among those exits, pick the one whose **resulting tile
  minimizes `dist²(nextTile, targetTile)`**.
- **Tie-break:** if two or more exits are equidistant, prefer in this strict order:
  `UP > LEFT > DOWN > RIGHT`. (This reproduces the classic deterministic tie-break.)
- **No-up zones (§4.6):** on specific tiles, ghosts may not choose `UP`.
- A ghost's target tile is recomputed every frame but only *acted upon* at tile centers.

### 4.1 Blinky (red) — direct chase
```
target_chase(Blinky) = player.tile
```
Blinky targets the player's current tile directly.

### 4.2 Pinky (pink) — ambush
```
ahead = player.tile + 4 * player.dir
if player.dir == UP:
    ahead = player.tile + 4*UP + 4*LEFT   # reproduce the original overflow bug
target_chase(Pinky) = ahead
```
Pinky targets 4 tiles ahead of the player's facing direction. **The classic UP bug is
intentional and required:** when the player faces UP, the target is shifted 4 tiles up
*and* 4 tiles left. (See D-004 — we deliberately preserve this for fidelity.)

### 4.3 Inky (cyan) — flank, derived from Blinky
```
pivot = player.tile + 2 * player.dir
if player.dir == UP:
    pivot = player.tile + 2*UP + 2*LEFT    # same UP overflow as Pinky
vector = pivot - Blinky.tile               # from Blinky to the pivot
target_chase(Inky) = Blinky.tile + 2 * vector   # double that vector from Blinky
# equivalently: target = pivot + (pivot - Blinky.tile) = 2*pivot - Blinky.tile
```
Inky takes the tile 2 ahead of the player, draws a vector from Blinky to that point,
doubles it, and targets the endpoint. Inky's behavior therefore depends on Blinky's live
position. The same UP overflow applies to the 2-ahead pivot.

### 4.4 Clyde (orange) — shy
```
d2 = dist²(Clyde.tile, player.tile)
if d2 >= 8*8:               # 8 tiles or farther (use squared: 64)
    target_chase(Clyde) = player.tile        # behaves like Blinky
else:                       # closer than 8 tiles
    target_chase(Clyde) = Clyde.scatterCorner # flees to his corner
```
Clyde chases directly when 8 or more tiles from the player, but retreats to his scatter
corner when within 8 tiles. This makes him oscillate near the player.

### 4.5 Scatter corners (fixed, off-grid by design)
Each ghost has a fixed scatter target *outside* the play area so it loops around its
corner. Exact tiles from the canonical map; nominal values:
| Ghost  | Corner            | Scatter target tile (col,row) |
|--------|-------------------|-------------------------------|
| Blinky | top-right         | (25, -3) approx → (25, 0)      |
| Pinky  | top-left          | (2, -3) approx → (2, 0)        |
| Inky   | bottom-right      | (27, 31)                       |
| Clyde  | bottom-left       | (0, 31)                        |

(The negative/off-map rows are clamped to the canonical map's documented values; the
point is each ghost circles a distinct corner.)

### 4.6 No-up tiles
- At a small set of tiles (the four tiles just above each side of the central area, per
  the canonical map, including the tiles above the ghost-house exit), a ghost in
  `SCATTER` or `CHASE` may **not** select `UP`. This constraint does **not** apply in
  `FRIGHTENED` or `EATEN` modes.
- **Acceptance:** at a marked no-up tile, `UP` is never present in the candidate exit
  set for a scatter/chase ghost, even if it would minimize distance.

### 4.7 Ghost-house exit order & timing
- Blinky starts outside. Pinky leaves almost immediately. Inky and Clyde leave based on a
  **dot counter**: Inky leaves after **30** pellets eaten (level 1); Clyde after **60**
  (level 1). After a life is lost, a global dot counter governs release (Pinky 7, Inky
  17, Clyde 32) — Developer may implement the simpler per-ghost counter for v1 and note
  the deviation in `docs/decisions.md`. (See D-006.)
- Ghosts exit by moving to the door tile, then up onto `GATE_PATH`, then turning into the
  maze (initial direction LEFT).

### 4.8 Ghost targeting — acceptance (highest correctness risk)
- For a fixed player tile/direction and Blinky position, each ghost's `target_chase`
  returns the exact tile given by the formulas above. These are **unit-tested with table
  cases**, including:
  - Pinky/Inky UP-overflow cases (player facing UP).
  - Clyde crossing the 8-tile boundary (d²=63 vs d²=64).
  - Inky when Blinky is on the opposite side of the player.
- The turn-decision picks the documented exit including the `UP>LEFT>DOWN>RIGHT`
  tie-break, verified at a junction with two equidistant exits.

---

## 5. Mode state machine (scatter / chase / frightened / eaten)

### 5.1 Modes
- `SCATTER` — ghost heads to its scatter corner (§4.5).
- `CHASE` — ghost heads to its per-personality target (§4.1–4.4).
- `FRIGHTENED` — ghost is edible, moves at reduced speed, turns **pseudo-randomly**
  (see §5.5), renders blue/flashing.
- `EATEN` — ghost has been eaten; only its eyes remain, it returns to the house at high
  speed, then re-enters as `SCATTER`/`CHASE` per the global timer.

### 5.2 Scatter/chase phase timer (per level band)
A single global timer drives scatter↔chase for all non-frightened ghosts. Frightened
time does **not** advance this timer (it is paused while frightened; see §5.4).

**Level 1 schedule (seconds):**
| Phase | Mode    | Duration |
|-------|---------|----------|
| 1     | SCATTER | 7        |
| 2     | CHASE   | 20       |
| 3     | SCATTER | 7        |
| 4     | CHASE   | 20       |
| 5     | SCATTER | 5        |
| 6     | CHASE   | 20       |
| 7     | SCATTER | 5        |
| 8     | CHASE   | ∞ (until level ends) |

**Levels 2–4:**
| Phase | Mode    | Duration |
|-------|---------|----------|
| 1     | SCATTER | 7        |
| 2     | CHASE   | 20       |
| 3     | SCATTER | 7        |
| 4     | CHASE   | 20       |
| 5     | SCATTER | 5        |
| 6     | CHASE   | 1033     |
| 7     | SCATTER | 1/60 (≈ one frame) |
| 8     | CHASE   | ∞        |

**Levels 5+:**
| Phase | Mode    | Duration |
|-------|---------|----------|
| 1     | SCATTER | 5        |
| 2     | CHASE   | 20       |
| 3     | SCATTER | 5        |
| 4     | CHASE   | 20       |
| 5     | SCATTER | 5        |
| 6     | CHASE   | 1037     |
| 7     | SCATTER | 1/60     |
| 8     | CHASE   | ∞        |

### 5.3 Frightened mode
- Entering `FRIGHTENED`: triggered when the player eats a power pellet. **All ghosts
  currently in `SCATTER` or `CHASE`** switch to `FRIGHTENED`. Ghosts in `EATEN` are not
  affected; ghosts still inside the house at that moment are not turned frightened.
- On entering frightened, all affected ghosts **reverse direction immediately** (§5.4).
- Duration & flashing per level (§8 table). When the timer reaches the flash threshold,
  ghosts blink between blue and white as a "about to end" warning.
- Eating a second power pellet while frightened **resets** the frightened timer to the
  current level's full duration and **resets the eat-chain** value back to 200 for the
  next ghost eaten? — **No.** The chain resets to 200 only when a *new* frightened window
  starts via a power pellet. Resetting the timer also resets the chain to 200. (See
  D-005 for the precise rule chosen.)
- **Speed:** frightened ghosts move at reduced speed (§8).

### 5.4 Forced reversal
- Whenever the global mode flips `SCATTER↔CHASE`, **and** at the moment frightened
  begins, every affected ghost reverses direction once (a one-time 180°), then resumes
  normal turn rules. Reversal does not occur when frightened *ends* (ghosts simply resume
  the underlying scatter/chase target).

### 5.5 Frightened movement (pseudo-random, deterministic & testable)
- At each tile center while frightened, the ghost picks a direction using a
  **seeded PRNG** (so runs are reproducible in tests):
  ```
  candidates = exits excluding 180° reversal (same as normal)
  prefer order is NOT used; instead:
  pick = candidates[ prng.nextInt(candidates.length) ]
  ```
- The PRNG is seeded deterministically at game start (and the seed is logged), so a test
  with a fixed seed asserts a fixed frightened path.

### 5.6 Eaten mode
- Set when a frightened ghost is eaten by the player (§6.3). The ghost becomes "eyes,"
  targets the ghost-house door, moves at `EATEN` speed (fastest), passes through the door
  into the house, pauses briefly, then re-enters play in the current global mode.

### 5.7 Acceptance
- With a fixed seed, a frightened ghost's sequence of turn choices is reproducible.
- A power pellet eaten mid-chase reverses all live ghosts within the same frame they
  enter frightened.
- The scatter/chase timer does not advance while any frightened window is active and
  resumes from where it paused afterward.

---

## 6. Scoring

### 6.1 Score table
| Event                        | Points |
|------------------------------|--------|
| Standard pellet              | 10     |
| Power pellet                 | 50     |
| Ghost eaten — 1st in chain   | 200    |
| Ghost eaten — 2nd in chain   | 400    |
| Ghost eaten — 3rd in chain   | 800    |
| Ghost eaten — 4th in chain   | 1600   |
| Bonus fruit (see §6.4)       | 100–5000 (per table) |

### 6.2 Ghost eat-chain
- The chain counter starts at 200 each time a **new** frightened window begins (a power
  pellet is eaten). The 1st ghost eaten in that window scores 200, the 2nd 400, the 3rd
  800, the 4th 1600. Eating all four in one window scores `200+400+800+1600 = 3000`.
- The chain does **not** persist across power pellets: a new power pellet restarts at 200.
- Eating a ghost briefly pauses both actors and shows the score popup; gameplay resumes
  after the popup interval.

### 6.3 Eating a ghost
- A ghost is eaten when the **player's tile equals a `FRIGHTENED` ghost's tile**. The
  ghost transitions to `EATEN` (§5.6) and the chain value is awarded and advanced.
- A ghost in `SCATTER`, `CHASE`, or `EATEN` is **not** edible; tile-overlap with such a
  ghost kills the player (§7.2).

### 6.4 Bonus fruit
- A bonus fruit appears below the ghost house after **70** pellets eaten and again after
  **170** pellets eaten in a level (two appearances per level).
- Each appearance lasts **9–10 seconds** (use 9.5 s; configurable) then disappears.
- Fruit type and value scale with level:
  | Level | Fruit (internal name) | Points |
  |-------|-----------------------|--------|
  | 1     | cherry                | 100    |
  | 2     | strawberry            | 300    |
  | 3–4   | orange                | 500    |
  | 5–6   | apple                 | 700    |
  | 7–8   | melon                 | 1000   |
  | 9–10  | galaxian              | 2000   |
  | 11–12 | bell                  | 3000   |
  | 13+   | key                   | 5000   |
- (Fruit *art* is original; internal names map to value tiers only.)

### 6.5 Extra life
- The player earns **one** extra life when the score first reaches **10,000** points.
- This is a one-time award in v1 (no repeating bonus lives). (See D-007.)

### 6.6 Acceptance
- Eating four ghosts in one frightened window yields exactly 3000 chain points; a fifth
  ghost is impossible (only four exist).
- Crossing 10,000 points exactly once increments lives by 1; crossing it again (after
  losing and regaining) does not award a second life.
- Pellet/power-pellet/fruit point values match the tables exactly.

---

## 7. Lives, win/lose, level progression

### 7.1 Lives
- The player starts with **3 lives** (the on-screen reserve shows the lives held *besides*
  the one in play, classic-style: start = 1 active + 2 reserve icons; total 3).
- Losing the active life decrements the count; when it reaches 0 after a death, the game
  ends → Game Over screen.

### 7.2 Death (lose a life)
- The player dies when its tile equals a non-frightened, non-eaten ghost's tile
  (`SCATTER`/`CHASE`).
- On death: freeze, play the death animation, decrement lives, then:
  - lives remaining > 0 → reset actor positions (player and all ghosts to start), keep
    eaten pellets/score/level, resume after a short pause.
  - lives remaining == 0 → Game Over.

### 7.3 Level clear (win the level)
- A level is cleared when **all 244 pellets** (240 + 4 power) are eaten.
- On clear: freeze ghosts, play a brief maze-flash, then load the **next level** with the
  same maze, full pellets, increased difficulty (§8), and reset actor positions.

### 7.4 Game over / win state
- **Game Over** when lives reach 0. Show final score and high score; offer restart.
- There is no "final win" — levels continue indefinitely with difficulty capping at the
  level-5+ band; the practical goal is high score. (See D-008.)

### 7.5 Acceptance
- Eating the last pellet advances the level counter by 1 and restores 244 pellets.
- Dying with 1 life remaining shows Game Over and persists the high score (§10).
- Difficulty parameters for level N match the §8 table.

---

## 8. Difficulty / per-level parameters

Speeds are expressed as a **percentage of base speed** (base = 100% = full
tile-step speed used for the player at level 1). All actors derive their pixel/sec from
this percentage so 60 fps timing is consistent.

| Level | Player speed | Player (frightened, eating dots) | Ghost speed | Ghost tunnel speed | Frightened ghost speed | Frightened time (s) | # flashes near end |
|-------|--------------|----------------------------------|-------------|--------------------|------------------------|---------------------|--------------------|
| 1     | 80%          | 90%                              | 75%         | 40%                | 50%                    | 6                   | 5                  |
| 2     | 90%          | 95%                              | 85%         | 45%                | 55%                    | 5                   | 5                  |
| 3     | 90%          | 95%                              | 85%         | 45%                | 55%                    | 4                   | 5                  |
| 4     | 90%          | 95%                              | 85%         | 45%                | 55%                    | 3                   | 5                  |
| 5     | 100%         | 100%                             | 95%         | 50%                | 60%                    | 2                   | 5                  |
| 6–8   | 100%         | 100%                             | 95%         | 50%                | 60%                    | 1                   | 3                  |
| 9–10  | 100%         | 100%                             | 95%         | 50%                | (none) 0               | 0 (no frightened*)  | 0                  |
| 11+   | 100% (90% L21+) | 100%                          | 95%         | 50%                | 0                      | 0                   | 0                  |

\* From level 9+ in the classic game, eating a power pellet **does not** make ghosts
edible (frightened time = 0). We keep this: power pellets still score 50 and still force
one reversal, but ghosts are not edible. (See D-009.) Developer may simplify the 11+ band
to a single "max difficulty" row and note it in decisions.

**"Elroy" (Blinky speedup):** when few pellets remain, Blinky speeds up slightly and
prefers chase. v1 may **omit** Elroy for simplicity; if omitted, log it in
`docs/decisions.md` (D-010) and Blinky uses the table ghost speed throughout.

### 8.1 Acceptance
- For each level band, the runtime speed multipliers and frightened duration equal the
  table (unit-tested by reading the difficulty config for a given level).
- Tunnel speed is applied only while an actor's tile is a `TUNNEL` tile.

---

## 9. Player stories & acceptance criteria

Each story is independently testable. "Done" = all its criteria pass.

**S-01 — Move through the maze.**
*As a player, I want to steer through corridors with swipes/D-pad so movement feels
precise.*
- AC1: A swipe/press sets `desiredDir`; the turn applies at the next legal tile center.
- AC2: The player never overlaps a wall; into a wall it stops flush at center.
- AC3: Buffered input set up to 2 tiles early is honored at the first legal tile.

**S-02 — Eat pellets and clear the level.**
*As a player, when I clear every pellet, I advance to a harder level.*
- AC1: Each pellet eaten adds 10; each power pellet adds 50.
- AC2: Eating the 244th pellet triggers level clear and loads level N+1 with full pellets.
- AC3: Level N's difficulty matches §8.

**S-03 — Power pellet & frightened ghosts.**
*As a player, when I eat a power pellet, all live ghosts turn blue and become edible for
N seconds, and the eat-chain scores 200/400/800/1600.*
- AC1: On power-pellet, all `SCATTER`/`CHASE` ghosts enter `FRIGHTENED` and reverse once.
- AC2: Frightened duration equals the §8 value for the current level; ghosts flash before
  it ends.
- AC3: Eating frightened ghosts in one window scores 200, 400, 800, 1600 in order; all
  four = 3000.
- AC4: An eaten ghost becomes eyes, returns home, and re-enters play.
- AC5: From level 9+, a power pellet does not make ghosts edible (still +50, still
  reverses).

**S-04 — Distinct ghost personalities.**
*As a player, the four ghosts should feel different so the maze stays tense.*
- AC1: Blinky targets my tile; Pinky 4 ahead (with UP bug); Inky uses the Blinky-derived
  vector; Clyde chases far / flees within 8 tiles. (Unit-tested per §4.8.)
- AC2: Ghosts alternate scatter/chase per the §5.2 schedule for the level.
- AC3: On each scatter↔chase flip, live ghosts reverse once.

**S-05 — Lives & death.**
*As a player, colliding with a dangerous ghost costs a life.*
- AC1: Tile-overlap with a `SCATTER`/`CHASE` ghost causes death; with a `FRIGHTENED`
  ghost causes an eat.
- AC2: Death decrements lives and resets positions; 0 lives → Game Over.
- AC3: Start lives = 3 (1 active + 2 reserve icons).

**S-06 — Bonus fruit.**
*As a player, a fruit appears so I can grab extra points.*
- AC1: Fruit appears at 70 and 170 pellets eaten; lasts ~9.5 s; disappears if not taken.
- AC2: Fruit value matches the level tier (§6.4).

**S-07 — Extra life.**
*As a player, reaching a score threshold grants a bonus life.*
- AC1: Crossing 10,000 points grants exactly one life, one time.

**S-08 — Persistence & offline.**
*As a player, my high score is remembered and the game works with no network.*
- AC1: High score persists across app restarts (local storage).
- AC2: The app makes zero network calls; works in airplane mode (§11).

**S-09 — Pause/resume & screen flow.**
*As a player, I can pause and navigate start/game-over screens.*
- AC1: Start → gameplay → (pause/resume) → game-over → restart all reachable.
- AC2: Pausing freezes the simulation; resuming continues deterministically.

---

## 10. Persistence (local only)
- Persist: high score (integer), and optionally last-reached level and audio on/off.
- Storage: on-device key-value (e.g. `shared_preferences`); no files leave the device.
- **Acceptance:** setting a new high score and relaunching shows the persisted value; a
  fresh install shows high score 0.

---

## 11. Non-functional requirements

- **NFR-01 Frame rate.** Sustained **60 fps** on mid-range 2020-era phones during normal
  play (all actors moving, frightened active). No per-frame heap allocations in the game
  loop; ghost targeting must be O(1) per ghost per tile. *Verify:* on-device frame-time
  overlay stays ≤ 16.7 ms p95 over a 3-minute session.
- **NFR-02 App size.** Release **APK/IPA ≤ 60 MB** (download size). Placeholder budget;
  may tighten after final art. *Verify:* CI reports build size under budget.
- **NFR-03 Offline-only.** **Zero** network calls; no backend, analytics, ads, or online
  leaderboard in v1. *Verify:* static check for networking libs/usages; functional check
  in airplane mode.
- **NFR-04 Supported OS.** **Android 8.0 (API 26)+** and **iOS 13+**. *Verify:* manifest
  `minSdkVersion=26`; iOS deployment target 13.0; smoke test on each minimum.
- **NFR-05 Orientation & input.** Portrait primary; touch controls (swipe and/or on-screen
  D-pad per Designer's control spec). Works on screens from ~4.7" up.
- **NFR-06 Determinism for tests.** Core simulation (movement, targeting, timers,
  frightened PRNG) is deterministic given a seed and an input script, enabling
  replay/unit tests.
- **NFR-07 Accessibility (baseline).** Color-blind-safe distinction between ghosts and
  frightened state (shape/flash, not color alone); minimum touch target 44×44 pt for UI
  buttons.
- **NFR-08 Battery/thermals.** Cap to display refresh; do not busy-spin. No background
  execution when paused/backgrounded.

---

## 12. Out of scope (v1)
- Backend, accounts, cloud save, online/global leaderboards.
- Multiplayer / 2-player alternating mode.
- In-app purchases, ads, telemetry.
- Level editor, alternate mazes (single canonical maze only).
- Elroy mode and the precise global ghost-house dot counter are *optional* for v1 (see
  D-006, D-010); if cut, they must be logged in `docs/decisions.md`.

---

## 13. Definition of "Done" (per feature)
A feature is Done when: (a) it satisfies every acceptance criterion in its story/section;
(b) it has the required automated tests (unit for targeting/scoring/level-clear/frightened
timer; golden for maze & HUD); (c) it holds 60 fps per NFR-01; (d) any deviation from this
spec is recorded in `docs/decisions.md` and signed off by the Requirements Engineer.

---

## 14. Prioritized backlog (v1)
P0 = required to call it the game; P1 = needed for a faithful feel; P2 = polish.

| ID  | Item                                                | Priority |
|-----|-----------------------------------------------------|----------|
| B01 | Tilemap load + maze render (golden)                 | P0       |
| B02 | Player grid movement + buffered input               | P0       |
| B03 | Pellet/power-pellet placement, eating, level clear  | P0       |
| B04 | Scatter/chase FSM + global phase timer              | P0       |
| B05 | Ghost targeting: Blinky/Pinky/Inky/Clyde (unit)     | P0       |
| B06 | Frightened mode + eat-chain scoring                 | P0       |
| B07 | Lives, death, reset, Game Over                      | P0       |
| B08 | HUD: score, lives, level (golden)                   | P0       |
| B09 | High-score persistence (offline)                    | P0       |
| B10 | Difficulty scaling per level (§8)                   | P1       |
| B11 | Bonus fruit (appearance, timing, value)             | P1       |
| B12 | Tunnel wrap + tunnel speed                           | P1       |
| B13 | Ghost-house exit timing (dot counters)              | P1       |
| B14 | Extra life at 10k                                   | P1       |
| B15 | Start/pause/game-over screens + flow                | P1       |
| B16 | Audio sfx (eat, power, eat-ghost, death)            | P2       |
| B17 | Score popups / screen juice                         | P2       |
| B18 | Color-blind-safe states, accessibility pass         | P2       |
| B19 | Elroy mode (optional fidelity)                      | P2       |
