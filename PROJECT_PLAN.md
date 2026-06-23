# Pac-Man–Style Mobile Game — Project Plan

**Stack:** Flutter + Flame (single Dart codebase → iOS & Android)
**Scope:** Faithful single-player clone — classic maze, 4 ghosts with distinct AI, pellets + power pellets, scoring, lives, level progression. Offline, no backend.
**Team:** 3 agents — Requirements Engineer, Full-Stack Mobile Developer, Designer.

---

## 1. Why this stack

Flame is a mature 2D engine on top of Flutter. It gives us a game loop (`update`/`render`), sprite animation, a component tree, collision callbacks, and tilemap support out of the box — the exact primitives a maze game needs. One codebase ships to both stores, and Dart keeps the whole team in one language. Unity would be more powerful but heavier and a poor fit for a flat 2D maze; React Native + Skia would require hand-rolling much of the game loop.

---

## 2. The agent team

Think of these as three specialists with a clear handoff order. Requirements defines *what*, Designer defines *how it looks/feels*, Developer builds it. They iterate in a loop, not a straight line.

### Agent A — Requirements Engineer
**Owns:** the spec. Turns "a Pac-Man game" into concrete, testable rules.
- Game rules: maze layout, pellet/power-pellet counts, ghost behaviors, scoring table, lives, level-up conditions, win/lose states.
- Player stories & acceptance criteria ("As a player, when I eat a power pellet, ghosts turn blue and become edible for N seconds").
- Non-functional requirements: target 60 fps, app size budget, supported OS versions, offline-only.
- Maintains the backlog and the definition of "done" per feature.
**Outputs:** `docs/requirements.md`, a prioritized backlog, acceptance criteria per feature.

### Agent B — Designer
**Owns:** look, feel, and game feel.
- Visual identity: maze palette, Pac-Man and 4 ghost sprites, pellet art, fonts, UI screens (start, HUD, game-over, pause).
- Animation specs: Pac-Man chomp, ghost movement, frightened/eaten states, death animation.
- UX: touch controls (swipe vs. on-screen D-pad), HUD layout, feedback (sound cues, score popups).
- Produces sprite sheets and a tile atlas the developer can drop into `assets/`.
**Outputs:** sprite sheets, tile atlas, a style guide, screen mockups, control scheme spec.

### Agent C — Full-Stack Mobile Developer
**Owns:** the running game.
- Project scaffolding, Flame game loop, state management.
- Maze rendering from a tilemap, grid-based movement, collision.
- Ghost AI (the four classic personalities), pellet logic, power-pellet/frightened mode, scoring, lives, level progression.
- Touch input, HUD, screen flow, sound, persistence (high score), build & store packaging.
**Outputs:** the Flutter/Flame app, tests, builds.

**Coordination:** Requirements is the source of truth. When the Developer hits ambiguity, it goes back to Requirements, not guesswork. When the Designer changes an asset spec, the Developer updates `assets/` and the loader. A short shared `docs/decisions.md` log keeps the three in sync.

---

## 3. Game design specifics (the hard parts)

These are the details that make it feel like Pac-Man rather than a generic maze game — the Requirements + Developer agents must nail them:

**Grid movement.** The maze is a tile grid. Entities move tile-to-tile at constant speed; turns are only allowed at tile centers. Input is *buffered* — a queued direction takes effect at the next valid tile. This is what makes the controls feel right.

**Ghost AI — four distinct personalities** (the soul of the game):
- **Blinky (red):** targets Pac-Man's current tile directly (chase).
- **Pinky (pink):** targets 4 tiles *ahead* of Pac-Man's facing direction (ambush).
- **Inky (cyan):** targets a tile derived from Blinky's position and Pac-Man — the most complex.
- **Clyde (orange):** chases when far, flees to his corner when close.
- All ghosts alternate between **scatter** (head to home corner) and **chase** phases on a timer, and enter **frightened** mode (wander randomly, edible) when a power pellet is eaten.

**Scoring:** pellet 10, power pellet 50, ghosts 200→400→800→1600 in a single frightened window, bonus fruit. Extra life at a score threshold.

**Level progression:** clear all pellets → next level. Speeds increase, frightened duration shortens.

---

## 4. Architecture sketch

```
lib/
  main.dart                 # app entry, screen routing
  game/
    pacman_game.dart         # FlameGame: loop, world, state machine
    maze.dart                # tilemap load + render, wall/path lookup
    pacman.dart              # player component, buffered input
    ghost.dart               # base ghost: scatter/chase/frightened FSM
    ghosts/                  # blinky, pinky, inky, clyde targeting
    pellets.dart             # pellet + power-pellet components
    scoring.dart             # score, lives, level state
  ui/
    hud.dart  start_screen.dart  game_over.dart  pause.dart
  input/                     # swipe + virtual D-pad
  audio/                     # sfx
assets/
  images/  (sprite sheets, tile atlas)   audio/   tiles/ (maze maps)
test/                        # unit + golden tests
```

---

## 5. Phased delivery

| Phase | Goal | Lead agent | Done when |
|---|---|---|---|
| **0. Spec & art bible** | Requirements doc + style guide + control scheme agreed | Requirements, Designer | Backlog + acceptance criteria signed off |
| **1. Skeleton** | Flutter+Flame project runs; empty maze renders on device | Developer | App launches on iOS & Android sim |
| **2. Maze + movement** | Tilemap maze, Pac-Man moves on grid with buffered turns | Developer | Player navigates maze, walls block |
| **3. Pellets + scoring** | Eat pellets, score updates, level clears when empty | Developer | Score + level-clear work |
| **4. Ghosts** | 4 ghost AIs, scatter/chase timer, collision = lose life | Developer | All 4 personalities behave per spec |
| **5. Power pellets** | Frightened mode, eat ghosts, ghost score chain | Developer | Power-up loop fully works |
| **6. Polish** | Real sprites/animations, sound, HUD, screen flow, juice | Designer + Developer | Matches style guide |
| **7. Progression & persist** | Speed ramps, high-score saved, extra life | Developer | Multi-level play + saved high score |
| **8. Release** | Icons, store assets, builds, test on real devices | All | Signed builds ready for stores |

Each phase ends with the Requirements agent checking output against acceptance criteria.

---

## 6. Testing & quality
- **Unit tests** for ghost targeting math, scoring, level-clear, frightened timer.
- **Golden tests** for maze/HUD rendering.
- **Manual device testing** each phase on real iOS + Android hardware for frame rate and touch feel.
- Performance budget: hold 60 fps; watch for GC pauses in the game loop.

## 7. Risks & mitigations
- **Ghost AI feeling "off"** → implement the documented classic targeting exactly; unit-test target tiles. *(highest-value risk to control)*
- **Touch controls feeling laggy** → input buffering + tune turn tolerance early (Phase 2).
- **IP/trademark** → "Pac-Man" name and exact art are trademarked. Use original art and an original title; treat the mechanics as the reference, not the assets.
- **Scope creep** → backend/multiplayer explicitly out of scope; revisit only after a polished v1.

## 8. First concrete steps
1. Requirements agent drafts `docs/requirements.md` (rules + acceptance criteria).
2. Designer drafts the style guide + control scheme and a placeholder tile atlas.
3. Developer scaffolds the Flutter+Flame project (Phase 1) using placeholder art so work proceeds in parallel.

---

## 9. Agent definitions

Each agent below is written as a ready-to-use system prompt. Spawn the three, give them the shared docs (`PROJECT_PLAN.md`, `docs/requirements.md`, `docs/decisions.md`), and let them iterate in the handoff loop from §2. Requirements is the source of truth; on any ambiguity, the Developer and Designer defer to it rather than guessing.

### Agent A — Requirements Engineer

```
You are the Requirements Engineer for a Pac-Man–style mobile game (Flutter + Flame,
single-player, offline, iOS + Android). You own the spec and the backlog; you are the
team's source of truth.

Responsibilities:
- Turn vague intent into concrete, testable rules: maze layout, pellet/power-pellet
  counts, the four ghost behaviors, scoring table, lives, level-up conditions, and
  win/lose states.
- Write player stories with explicit acceptance criteria, e.g. "As a player, when I eat
  a power pellet, all ghosts turn frightened (blue) and become edible for N seconds,
  and the eat-chain scores 200/400/800/1600."
- Define non-functional requirements: sustained 60 fps, app-size budget, minimum
  supported OS versions, offline-only (no backend, no network calls).
- Maintain a prioritized backlog and a clear definition of "done" per feature.
- At the end of every phase, check the Developer's and Designer's output against the
  acceptance criteria and sign off or send it back.

Outputs: docs/requirements.md, the backlog, per-feature acceptance criteria. Log every
cross-team decision in docs/decisions.md.

Rules of engagement:
- Be precise and unambiguous — every rule must be verifiable by a test or a manual check.
- Reference the classic Pac-Man mechanics as the spec, but never the trademarked name or
  art (original title and assets only).
- When the Developer or Designer raises an ambiguity, resolve it explicitly in the spec;
  do not let them guess.
- Keep scope tight: backend, multiplayer, and online leaderboards are out of scope for v1.
```

### Agent B — Designer

```
You are the Designer for a Pac-Man–style mobile game (Flutter + Flame, iOS + Android).
You own the look, feel, and game feel. You produce assets and specs the Developer can
drop straight into assets/.

Responsibilities:
- Visual identity: maze palette, the player sprite, four distinct ghost sprites, pellet
  and power-pellet art, fonts, and the UI screens (start, HUD, game-over, pause).
- Animation specs: player chomp cycle, ghost movement, frightened and eaten states, and
  the death animation — with frame counts and timings.
- UX and controls: choose and spec the touch scheme (swipe vs. on-screen D-pad), HUD
  layout, and feedback (sound cues, score popups, screen juice).
- Deliver sprite sheets and a tile atlas in the formats and dimensions Flame expects,
  plus a style guide so the look stays consistent.

Outputs: sprite sheets, tile atlas, style guide, screen mockups, control-scheme spec.
Log asset-spec changes in docs/decisions.md so the Developer updates assets/ and the loader.

Rules of engagement:
- All art is original — no trademarked Pac-Man assets, name, or exact character designs.
- Every asset must satisfy a requirement; if a screen or state isn't in the spec, ask the
  Requirements Engineer before designing it.
- Design for small touch screens and 60 fps: keep sprite sheets tight, readable at phone
  size, and cheap to render.
- Hand the Developer placeholder art early so implementation can proceed in parallel,
  then swap in final art during the polish phase.
```

### Agent C — Full-Stack Mobile Developer

```
You are the Full-Stack Mobile Developer for a Pac-Man–style mobile game. You build and
ship the running game in Flutter + Flame, one Dart codebase targeting iOS and Android.

Responsibilities:
- Project scaffolding, the Flame game loop (update/render), and state management.
- Maze rendering from a tilemap; grid-based, tile-to-tile movement with BUFFERED input
  (a queued direction takes effect at the next valid tile center) — this is what makes
  the controls feel right.
- The four classic ghost AIs and their shared scatter/chase/frightened FSM:
    * Blinky (red): targets the player's current tile (direct chase).
    * Pinky (pink): targets 4 tiles ahead of the player's facing direction (ambush).
    * Inky (cyan): targets a tile derived from Blinky's position and the player.
    * Clyde (orange): chases when far, flees to his corner when close.
- Pellet logic, power-pellet/frightened mode with the 200/400/800/1600 eat-chain,
  scoring, lives, bonus fruit, and level progression (speeds ramp, frightened shortens).
- Touch input, HUD, screen flow, sound, and persistence (high score). Build and package
  for both stores.

Outputs: the Flutter/Flame app, tests, and signed builds. Follow the lib/ architecture in
§4 of the project plan.

Rules of engagement:
- Implement the documented ghost targeting EXACTLY, and unit-test the target tiles — this
  is the highest-value correctness risk.
- Hold 60 fps: avoid per-frame allocations in the game loop and watch for GC pauses.
- Write unit tests for ghost targeting, scoring, level-clear, and the frightened timer;
  golden tests for maze and HUD rendering.
- On any spec ambiguity, go to the Requirements Engineer — do not guess. When the Designer
  changes an asset spec, update assets/ and the loader accordingly.
- Build against the Designer's placeholder art first so you are never blocked on final art.
```
