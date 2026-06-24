#!/usr/bin/env python3
"""Generate FINAL pixel-art sprites for Chompire (replaces the placeholder PNGs).

This is the polish-phase upgrade of ``assets/gen_placeholder.py``. It writes the
exact same files at the exact same dimensions, cell sizes, cell order and
filenames (the loader in ``lib/game/pacman_game.dart`` is hardcoded to them):

    sprites/muncher.png   224x16  16x16 cells, 14x1
    sprites/ghosts.png    128x96  16x16 cells, 8x6
    sprites/pellets.png   32x8     8x8 cells, 4x1
    tiles/maze_atlas.png  64x32    8x8 cells, 8x4

All art is ORIGINAL (trademark avoidance, decision D-001) and uses the
style-guide palette. The placeholder generator is kept untouched for history;
this script is the reproducible source for the real art. Run:

    python3 assets/gen_art.py

Requires Pillow (PIL). Sprites are authored on a high-res (8x) canvas with a
hand-built pixel grid and nearest-neighbour downscale so every source pixel maps
to exactly one 16x16 (or 8x8) cell pixel -> crisp pixel art, no blur.
"""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))

# ---- Palette (docs/style-guide.md §2) --------------------------------------
PATH_BG   = (11, 11, 26, 255)     # #0B0B1A
WALL_FILL = (27, 42, 107, 255)    # #1B2A6B
WALL_EDGE = (59, 107, 255, 255)   # #3B6BFF
WALL_DIM  = (36, 56, 138, 255)    # #24388A
GATE      = (255, 179, 217, 255)  # #FFB3D9

MUNCH      = (255, 210, 63, 255)   # #FFD23F  muncher.body
MUNCH_SH   = (224, 162, 30, 255)   # #E0A21E  muncher.shade
MUNCH_HI   = (255, 233, 150, 255)  # warm highlight (derived, lighter body)

PELLET     = (255, 233, 176, 255)  # #FFE9B0
PELLET_HI  = (255, 248, 224, 255)  # pellet highlight
POWER      = (255, 210, 63, 255)   # #FFD23F
POWER_HI   = (255, 240, 190, 255)  # power highlight glow
FRUIT      = (255, 77, 77, 255)    # #FF4D4D berry
FRUIT_SH   = (198, 44, 44, 255)    # berry shade
FRUIT_HI   = (255, 150, 150, 255)  # berry highlight
LEAF       = (59, 196, 107, 255)   # #3BC46B

EMBER = (255, 77, 77, 255)    # #FF4D4D
ROSA  = (255, 138, 216, 255)  # #FF8AD8
AQUA  = (77, 225, 255, 255)   # #4DE1FF
TANGO = (255, 169, 77, 255)   # #FFA94D

FRIGHT = (37, 54, 200, 255)    # #2536C8
WHITE  = (255, 255, 255, 255)
IRIS   = (37, 54, 200, 255)    # #2536C8
FRIGHT_MOUTH = (255, 138, 216, 255)  # #FF8AD8
TRANSP = (0, 0, 0, 0)


def shade_of(color, factor=0.78):
    """A darker variant of a body colour for lower-right volume shading."""
    r, g, b, a = color
    return (int(r * factor), int(g * factor), int(b * factor), a)


def light_of(color, amt=70):
    r, g, b, a = color
    return (min(255, r + amt), min(255, g + amt), min(255, b + amt), a)


# ============================================================================
# Pixel-grid helper: author a NxN grid then place into a sheet.
# ============================================================================
class Grid:
    """A simple NxN RGBA pixel grid you draw on directly, then blit to a sheet."""

    def __init__(self, n):
        self.n = n
        self.px = [[TRANSP for _ in range(n)] for _ in range(n)]

    def set(self, x, y, color):
        if 0 <= x < self.n and 0 <= y < self.n and color is not None:
            self.px[y][x] = color

    def hline(self, x0, x1, y, color):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.set(x, y, color)

    def vline(self, x, y0, y1, color):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.set(x, y, color)

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, color)

    def to_image(self):
        im = Image.new("RGBA", (self.n, self.n), TRANSP)
        im.putdata([self.px[y][x] for y in range(self.n) for x in range(self.n)])
        return im


def blit(sheet, grid, cx, cy):
    sheet.paste(grid.to_image(), (cx, cy))


# ============================================================================
# Disc mask: 16x16 round body. Returns set of (x,y) inside the disc.
# ============================================================================
def disc_pixels(n=16, cx=7.5, cy=7.5, r=7.2):
    inside = set()
    for y in range(n):
        for x in range(n):
            dx = x - cx
            dy = y - cy
            if dx * dx + dy * dy <= r * r:
                inside.add((x, y))
    return inside


# ============================================================================
# 1. muncher.png — 224x16, 16x16 cells, 14x1
# ============================================================================
def muncher_cell(open_frac, face="R", squash=0.0, alpha=255):
    """Draw a Muncher disc with a wedge mouth.

    open_frac : 0..1 how wide the wedge opens (0 = closed).
    face      : 'R' chomp facing right, 'U' death facing up.
    squash    : 0..1 vertical flatten for the death collapse.
    alpha     : overall alpha (death fade).
    """
    import math

    g = Grid(16)
    cx, cy = 7.5, 7.5
    r = 7.2
    # squash flattens vertically (disc -> ellipse -> line) for death.
    ry = r * (1.0 - 0.95 * squash)

    # half-angle of the wedge, in radians. 0..~95 deg.
    half = math.radians(open_frac * 95.0)

    # direction the mouth points
    if face == "R":
        base = 0.0
    else:  # 'U' -> up (screen -y)
        base = -math.pi / 2

    body = (MUNCH[0], MUNCH[1], MUNCH[2], alpha)
    shade = (MUNCH_SH[0], MUNCH_SH[1], MUNCH_SH[2], alpha)
    hi = (MUNCH_HI[0], MUNCH_HI[1], MUNCH_HI[2], alpha)

    for y in range(16):
        for x in range(16):
            dx = x - cx
            dy = y - cy
            # elliptical body test (squash on y)
            ny = dy / (ry / r) if ry > 0 else dy * 99
            if dx * dx + ny * ny > r * r:
                continue
            # wedge cut-out: angle from center
            if half > 0:
                ang = math.atan2(dy, dx)
                # angular distance to mouth axis
                d = ang - base
                while d > math.pi:
                    d -= 2 * math.pi
                while d < -math.pi:
                    d += 2 * math.pi
                if abs(d) < half:
                    continue  # inside the mouth wedge -> empty
            # shading: lower-right rim (relative to facing-right baseline)
            dist = math.sqrt(dx * dx + dy * dy)
            col = body
            # highlight upper-left
            if dx < -1.5 and dy < -1.5 and dist > r - 3:
                col = hi
            # shade lower-right rim
            elif dx > 1.0 and dy > 1.0 and dist > r - 2.4:
                col = shade
            elif dist > r - 1.2:
                # outer rim slightly darker for definition on lower/right
                if dx + dy > 1.5:
                    col = shade
            g.set(x, y, col)
    return g


def gen_muncher():
    sheet = Image.new("RGBA", (224, 16), TRANSP)

    # cell 0 closed, 1 small mouth, 2 wide mouth (facing right)
    blit(sheet, muncher_cell(0.0, "R"), 0, 0)
    blit(sheet, muncher_cell(0.32, "R"), 16, 0)
    blit(sheet, muncher_cell(0.62, "R"), 32, 0)

    # cells 3..13 = death, 11 frames, facing UP. The wedge opens wider and
    # wider (swallowing the body), then the disc flattens to a line and fades.
    # Frames 0..6: mouth opens up to ~full. 7..9: collapse/flatten. 10: gone.
    for i in range(11):
        t = i / 10.0
        if i < 7:
            openf = 0.30 + (i / 6.0) * 0.70   # 0.30 -> 1.0
            squash = 0.0
            alpha = 255
        elif i < 10:
            openf = 1.0
            squash = (i - 6) / 4.0            # 0.25 -> 0.75 flatten
            alpha = int(255 * (1.0 - (i - 6) / 5.0))
        else:
            # last frame fully transparent
            blit(sheet, Grid(16), (3 + i) * 16, 0)
            continue
        blit(sheet, muncher_cell(openf, "U", squash=squash, alpha=alpha),
             (3 + i) * 16, 0)

    out = os.path.join(ROOT, "sprites", "muncher.png")
    sheet.save(out)
    return out


# ============================================================================
# 2. ghosts.png — 128x96, 16x16 cells, 8x6
# ============================================================================
SKIRT = {
    # per-shape: a function giving, for each x in 2..13, the bottom y of the
    # body at skirt phase `ph` (0/1). Larger y = longer downward tongue.
    # We describe the skirt as a list of "feet" segments.
}


def ghost_body(color, shape, phase):
    """16x16 ghost dome + wavy skirt (no eyes). Returns a Grid.

    shape: 'spike3' (Ember), 'bump4' (Rosa), 'bump3' (Aqua), 'wave2' (Tango).
    phase: 0/1 skirt animation phase (crests shift by half a wave).
    """
    g = Grid(16)
    body = color
    sh = shade_of(color, 0.80)

    # ---- dome: rounded top. Body occupies x 2..13. Top at y=1. -------------
    # Build a rounded-top column profile: for each x, the top y of the dome.
    # Use a near-circular dome over the upper half.
    top_for_x = {}
    for x in range(2, 14):
        # center 7.5, radius ~6 across, dome height
        dx = (x - 7.5)
        # circle of radius 6 -> top y
        val = 6.0 * 6.0 - dx * dx
        if val < 0:
            top = 7
        else:
            top = int(round(1 + (6.0 - (val ** 0.5))))
        top_for_x[x] = max(1, top)

    # ---- skirt: bottom profile per x, depends on shape + phase -------------
    bottom_for_x = ghost_bottom_profile(shape, phase)

    for x in range(2, 14):
        ytop = top_for_x[x]
        ybot = bottom_for_x.get(x, 12)
        for y in range(ytop, ybot + 1):
            g.set(x, y, body)

    # ---- shading: lower-right + skirt undersides ---------------------------
    for x in range(2, 14):
        ybot = bottom_for_x.get(x, 12)
        # darken the bottom-most row of each foot for volume
        g.set(x, ybot, sh)
        if x >= 9:
            # right side gets a vertical shade stripe
            for y in range(max(top_for_x[x], 8), ybot + 1):
                if g.px[y][x] == body and x >= 12:
                    g.set(x, y, sh)
    # subtle top highlight
    hi = light_of(color, 45)
    for x in range(4, 9):
        ytop = top_for_x[x]
        g.set(x, ytop, hi)
    return g


def ghost_bottom_profile(shape, phase):
    """Return dict x->bottom_y describing the wavy skirt feet.

    The silhouette differences are the colorblind cue (style-guide §2):
      Ember spike3 = 3 sharp triangular spikes
      Rosa  bump4  = 4 round bumps
      Aqua  bump3  = 3 round bumps
      Tango wave2  = 2 wide waves
    phase shifts the crest/notch pattern by half a wave for the walk cycle.
    """
    prof = {}
    xs = list(range(2, 14))           # 12 columns
    base = 13                          # nominal skirt baseline
    if shape == "spike3":
        # 3 spikes across 12 cols -> 4 col segments each.
        # spikes are tall points; notches between are short.
        # phase swaps which positions are points vs notches (shift by 2 cols).
        seg = 4
        for x in xs:
            idx = x - 2
            local = idx % seg
            seg_no = idx // seg
            # point at the center of each segment
            tri = seg // 2
            depth = tri - abs(local - tri)        # 0..2 triangle
            ybot = base - 1 + depth                # spike reaches base+1
            if phase == 1:
                # shift: invert -> points become notches
                ybot = base + 1 - depth
            prof[x] = ybot
    elif shape in ("bump4", "bump3"):
        nb = 4 if shape == "bump4" else 3
        width = len(xs) / nb
        for x in xs:
            idx = x - 2
            b = int(idx / width)              # which bump
            center = (b + 0.5) * width
            # rounded bump: deeper near center of each bump
            d = abs((idx) - center) / (width / 2)
            d = min(1.0, d)
            depth = int(round((1 - d) * 2))   # 0..2
            ybot = base - 1 + depth
            if phase == 1:
                ybot = base - 1 + (2 - depth)  # invert crest/notch
            prof[x] = ybot
    else:  # wave2
        import math
        for x in xs:
            idx = x - 2
            # 2 sine waves across the width
            ph = 0 if phase == 0 else math.pi
            s = math.sin((idx / (len(xs) - 1)) * 2 * math.pi * 1.0 + ph)
            depth = int(round((s * 0.5 + 0.5) * 2))   # 0..2
            ybot = base - 1 + depth
            prof[x] = ybot
    return prof


def add_eyes(g, direction, eye_color=WHITE, iris_color=IRIS, small=False):
    """Two eyes looking in `direction` ('R','U','D','L')."""
    if small:
        # frightened: tiny 1x1 pale eyes
        for ex in (5, 9):
            g.set(ex, 6, eye_color)
            g.set(ex + 1, 6, eye_color)
        return g

    # white of the eye: 3 wide x 4 tall ovals at two positions
    lx, rx = 4, 9
    ey0 = 4
    for ex in (lx, rx):
        # rounded eye white (3x4 with corners trimmed)
        g.rect(ex + 1, ey0, ex + 2, ey0 + 3, eye_color)
        g.rect(ex, ey0 + 1, ex + 3, ey0 + 2, eye_color)
    # iris offset per direction
    off = {"R": (2, 1), "U": (1, 0), "D": (1, 2), "L": (0, 1)}[direction]
    for ex in (lx, rx):
        ix = ex + off[0]
        iy = ey0 + off[1]
        g.set(ix, iy, iris_color)
        g.set(ix + 1, iy, iris_color)
        g.set(ix, iy + 1, iris_color)
        g.set(ix + 1, iy + 1, iris_color)
    return g


def frightened_body(color, phase):
    """Frightened ghost: solid body (blue or white) + wavy mouth + small eyes."""
    g = ghost_body(color, "bump4", phase)
    # overwrite eyes area / give it a face: two small pale eyes
    eye = WHITE if color == FRIGHT else FRIGHT  # contrast on white frame
    for ex in (5, 9):
        g.set(ex, 5, eye)
        g.set(ex + 1, 5, eye)
        g.set(ex, 6, eye)
        g.set(ex + 1, 6, eye)
    # pink wavy mouth (zig-zag) around y 9-10
    mouth = FRIGHT_MOUTH
    mxs = range(4, 12)
    for i, mx in enumerate(mxs):
        my = 9 if i % 2 == 0 else 10
        g.set(mx, my, mouth)
    return g


def gen_ghosts():
    sheet = Image.new("RGBA", (128, 96), TRANSP)
    rows = [
        (EMBER, "spike3"),
        (ROSA,  "bump4"),
        (AQUA,  "bump3"),
        (TANGO, "wave2"),
    ]
    # cell order: mv0R,mv1R,mv0U,mv1U,mv0D,mv1D,mv0L,mv1L
    dirs = ["R", "R", "U", "U", "D", "D", "L", "L"]
    phases = [0, 1, 0, 1, 0, 1, 0, 1]

    for row, (color, shape) in enumerate(rows):
        for col in range(8):
            g = ghost_body(color, shape, phases[col])
            add_eyes(g, dirs[col])
            blit(sheet, g, col * 16, row * 16)

    # row 4: frightened [blue0, blue1, white0, white1, transparent x4]
    blit(sheet, frightened_body(FRIGHT, 0), 0, 64)
    blit(sheet, frightened_body(FRIGHT, 1), 16, 64)
    blit(sheet, frightened_body(WHITE, 0), 32, 64)
    blit(sheet, frightened_body(WHITE, 1), 48, 64)

    # row 5: eaten eyes [R,U,D,L, transparent x4] — eyes only, no body
    for col, d in enumerate(["R", "U", "D", "L"]):
        g = Grid(16)
        # slightly bigger / centered eyes since no body to anchor
        add_eyes(g, d)
        blit(sheet, g, col * 16, 80)

    out = os.path.join(ROOT, "sprites", "ghosts.png")
    sheet.save(out)
    return out


# ============================================================================
# 3. pellets.png — 32x8, 8x8 cells, 4x1
# ============================================================================
def gen_pellets():
    sheet = Image.new("RGBA", (32, 8), TRANSP)

    def cell8():
        return Grid(8)

    # cell 0: small pellet (3x3 with highlight) centered
    g0 = cell8()
    g0.rect(3, 3, 4, 4, PELLET)
    g0.set(2, 3, PELLET)
    g0.set(5, 4, PELLET)
    g0.set(3, 2, PELLET)
    g0.set(4, 5, PELLET)
    g0.set(3, 3, PELLET_HI)   # highlight
    blit(sheet, _g8(g0), 0, 0)

    # cell 1: power pellet ON ~6px amber circle + glow highlight
    g1 = cell8()
    power_disc = [
        (3, 1), (4, 1),
        (2, 2), (3, 2), (4, 2), (5, 2),
        (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3),
        (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4),
        (2, 5), (3, 5), (4, 5), (5, 5),
        (3, 6), (4, 6),
    ]
    for (x, y) in power_disc:
        g1.set(x, y, POWER)
    # highlight upper-left + glow
    g1.set(2, 2, POWER_HI)
    g1.set(3, 2, POWER_HI)
    g1.set(2, 3, POWER_HI)
    blit(sheet, _g8(g1), 8, 0)

    # cell 2: power OFF (blink) -> transparent (leave empty)

    # cell 3: berry fruit + leaf
    g3 = cell8()
    berry = [
        (2, 3), (3, 3), (4, 3), (5, 3),
        (2, 4), (3, 4), (4, 4), (5, 4),
        (3, 5), (4, 5),
    ]
    for (x, y) in berry:
        g3.set(x, y, FRUIT)
    # shade lower-right, highlight upper-left
    g3.set(5, 4, FRUIT_SH)
    g3.set(4, 5, FRUIT_SH)
    g3.set(2, 3, FRUIT_HI)
    g3.set(3, 3, FRUIT_HI)
    # green leaf/stem on top
    g3.set(4, 1, LEAF)
    g3.set(3, 2, LEAF)
    g3.set(4, 2, LEAF)
    g3.set(5, 2, LEAF)
    blit(sheet, _g8(g3), 24, 0)

    out = os.path.join(ROOT, "sprites", "pellets.png")
    sheet.save(out)
    return out


def _g8(grid8):
    """Wrap an 8-grid so blit() (which reads .to_image) works at 8x8."""
    return grid8


# ============================================================================
# 4. maze_atlas.png — 64x32, 8x8 cells, 8x4  (procedural walls used in-game;
#    this stays a clean readable atlas matching the placeholder spec)
# ============================================================================
def gen_maze_atlas():
    from PIL import ImageDraw

    CELL = 8
    img = Image.new("RGBA", (64, 32), TRANSP)
    d = ImageDraw.Draw(img)

    def box(idx):
        col = idx % 8
        row = idx // 8
        x0 = col * CELL
        y0 = row * CELL
        return x0, y0, x0 + CELL - 1, y0 + CELL - 1

    def fill(idx, color):
        x0, y0, x1, y1 = box(idx)
        d.rectangle([x0, y0, x1, y1], fill=color)

    def edge(idx, sides, color=WALL_EDGE):
        x0, y0, x1, y1 = box(idx)
        if "T" in sides:
            d.line([x0, y0, x1, y0], fill=color)
        if "B" in sides:
            d.line([x0, y1, x1, y1], fill=color)
        if "L" in sides:
            d.line([x0, y0, x0, y1], fill=color)
        if "R" in sides:
            d.line([x1, y0, x1, y1], fill=color)

    fill(0, PATH_BG)
    fill(1, WALL_FILL); edge(1, "TB")
    fill(2, WALL_FILL); edge(2, "LR")
    fill(3, WALL_FILL); edge(3, "TL")
    fill(4, WALL_FILL); edge(4, "TR")
    fill(5, WALL_FILL); edge(5, "BL")
    fill(6, WALL_FILL); edge(6, "BR")
    fill(7, WALL_FILL); edge(7, "TBLR")
    # inner dim accent on the junction for a touch of depth
    x0, y0, x1, y1 = box(7)
    d.rectangle([x0 + 2, y0 + 2, x1 - 2, y1 - 2], outline=WALL_DIM)

    # 8 gate: pink bar
    fill(8, PATH_BG)
    x0, y0, x1, y1 = box(8)
    cy = y0 + CELL // 2 - 1
    d.rectangle([x0, cy, x1, cy + 1], fill=GATE)
    # 9,10 tunnel edges (open path)
    fill(9, PATH_BG)
    fill(10, PATH_BG)
    # 11-31 reserved transparent (already)

    out = os.path.join(ROOT, "tiles", "maze_atlas.png")
    img.save(out)
    return out


def main():
    made = [
        gen_muncher(),
        gen_ghosts(),
        gen_pellets(),
        gen_maze_atlas(),
    ]
    for p in made:
        sz = os.path.getsize(p)
        print(f"{sz:>8} bytes  {p}")


if __name__ == "__main__":
    main()
