#!/usr/bin/env python3
"""Generate placeholder art + audio stubs for Chompire.

Matches assets/PLACEHOLDER.md exactly: cell sizes, sheet layouts, colours,
cell order. When final art is produced, replace the PNG bytes at identical
dimensions/cell order and keep this filename for reproducibility.

Run:  python3 assets/gen_placeholder.py
Requires Pillow (PIL). Audio stubs use the stdlib `wave` module (no deps).
"""
import math
import os
import struct
import wave
import zlib  # noqa: F401  (kept for parity; PIL handles PNG encoding)

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))

# ---- Palette (docs/style-guide.md) -----------------------------------------
PATH_BG   = (11, 11, 26, 255)     # #0B0B1A
WALL_FILL = (27, 42, 107, 255)    # #1B2A6B
WALL_EDGE = (59, 107, 255, 255)   # #3B6BFF
GATE      = (255, 179, 217, 255)  # #FFB3D9
MUNCH     = (255, 210, 63, 255)   # #FFD23F
PELLET    = (255, 233, 176, 255)  # #FFE9B0
FRUIT     = (255, 77, 77, 255)    # #FF4D4D
LEAF      = (59, 196, 107, 255)   # #3BC46B
EMBER     = (255, 77, 77, 255)    # #FF4D4D
ROSA      = (255, 138, 216, 255)  # #FF8AD8
AQUA      = (77, 225, 255, 255)   # #4DE1FF
TANGO     = (255, 169, 77, 255)   # #FFA94D
FRIGHT    = (37, 54, 200, 255)    # #2536C8
WHITE     = (255, 255, 255, 255)
IRIS      = (37, 54, 200, 255)    # #2536C8
TRANSP    = (0, 0, 0, 0)


def new_sheet(w, h):
    return Image.new("RGBA", (w, h), TRANSP)


# ============================================================================
# 1. maze_atlas.png  — 64x32, 8x8 cells, 8 cols x 4 rows
# ============================================================================
def gen_maze_atlas():
    CELL = 8
    img = new_sheet(64, 32)
    d = ImageDraw.Draw(img)

    def cell_box(idx):
        col = idx % 8
        row = idx // 8
        x0 = col * CELL
        y0 = row * CELL
        return x0, y0, x0 + CELL - 1, y0 + CELL - 1

    def fill(idx, color):
        x0, y0, x1, y1 = cell_box(idx)
        d.rectangle([x0, y0, x1, y1], fill=color)

    def edge(idx, sides):
        x0, y0, x1, y1 = cell_box(idx)
        if "T" in sides:
            d.line([x0, y0, x1, y0], fill=WALL_EDGE)
        if "B" in sides:
            d.line([x0, y1, x1, y1], fill=WALL_EDGE)
        if "L" in sides:
            d.line([x0, y0, x0, y1], fill=WALL_EDGE)
        if "R" in sides:
            d.line([x1, y0, x1, y1], fill=WALL_EDGE)

    # 0 path
    fill(0, PATH_BG)
    # 1 wall H: fill + top/bottom edge
    fill(1, WALL_FILL); edge(1, "TB")
    # 2 wall V: fill + left/right edge
    fill(2, WALL_FILL); edge(2, "LR")
    # 3-6 corners ┌┐└┘ : two relevant edges
    fill(3, WALL_FILL); edge(3, "TL")   # ┌
    fill(4, WALL_FILL); edge(4, "TR")   # ┐
    fill(5, WALL_FILL); edge(5, "BL")   # └
    fill(6, WALL_FILL); edge(6, "BR")   # ┘
    # 7 junction T/cross: fill + full border
    fill(7, WALL_FILL); edge(7, "TBLR")
    # 8 gate: 2px pink horizontal bar centered on path bg
    fill(8, PATH_BG)
    x0, y0, x1, y1 = cell_box(8)
    cy = y0 + CELL // 2 - 1
    d.rectangle([x0, cy, x1, cy + 1], fill=GATE)
    # 9 tunnel L (open path), 10 tunnel R (open path)
    fill(9, PATH_BG)
    fill(10, PATH_BG)
    # 11-31 reserved -> transparent (already)

    out = os.path.join(ROOT, "tiles", "maze_atlas.png")
    img.save(out)
    return out


# ============================================================================
# 2. muncher.png — 224x16, 16x16 cells, 14 cols x 1 row
# ============================================================================
def gen_muncher():
    CELL = 16
    img = new_sheet(224, 16)

    def disc(alpha=255):
        c = Image.new("RGBA", (CELL, CELL), TRANSP)
        dd = ImageDraw.Draw(c)
        col = (MUNCH[0], MUNCH[1], MUNCH[2], alpha)
        dd.ellipse([1, 1, 14, 14], fill=col)
        return c, dd

    cx, cy = 8, 8  # center

    def wedge(dd, half_angle):
        """Black wedge opening to the RIGHT (mouth faces +x)."""
        if half_angle <= 0:
            return
        # pieslice angles measured CW from 3 o'clock in PIL screen coords
        dd.pieslice([1, 1, 14, 14], -half_angle, half_angle,
                    fill=PATH_BG)

    # cell 0: closed (no mouth)
    c0, _ = disc()
    img.paste(c0, (0, 0))
    # cell 1: small wedge right
    c1, d1 = disc(); wedge(d1, 18)
    img.paste(c1, (16, 0))
    # cell 2: wide wedge right
    c2, d2 = disc(); wedge(d2, 40)
    img.paste(c2, (32, 0))
    # cells 3-13 death: shrinking circle, fading alpha 255->0 (last transparent)
    n = 11  # cells 3..13
    for i in range(n):
        t = i / (n - 1)  # 0..1
        alpha = int(round(255 * (1 - t)))
        radius = int(round(6.5 * (1 - t)))
        c = Image.new("RGBA", (CELL, CELL), TRANSP)
        dd = ImageDraw.Draw(c)
        if alpha > 0 and radius > 0:
            col = (MUNCH[0], MUNCH[1], MUNCH[2], alpha)
            dd.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                       fill=col)
        img.paste(c, ((3 + i) * 16, 0))

    out = os.path.join(ROOT, "sprites", "muncher.png")
    img.save(out)
    return out


# ============================================================================
# 3. ghosts.png — 128x96, 16x16 cells, 8 cols x 6 rows
# ============================================================================
def ghost_body(color, skirt_variant, wave_shift, shape):
    """Return a 16x16 RGBA ghost: dome + wavy/spiky skirt, no eyes.
    shape: 'spike3','bump4','bump3','wave2'  (colorblind silhouette cue).
    skirt_variant: 0 or 1 (animation phase).
    """
    c = Image.new("RGBA", (16, 16), TRANSP)
    d = ImageDraw.Draw(c)
    # dome: top rounded. Body spans x:2..13, dome top y:1
    d.ellipse([2, 1, 13, 12], fill=color)
    d.rectangle([2, 7, 13, 13], fill=color)

    base_y = 13
    if shape == "spike3":
        # 3 sharp triangular spikes
        pts = [2, 6, 10, 13]  # x boundaries -> 3 segments
        for i in range(3):
            x0 = pts[i]
            x1 = pts[i + 1]
            mid = (x0 + x1) // 2
            if (i + skirt_variant) % 2 == 0:
                d.polygon([(x0, base_y - 1), (mid, base_y + 2), (x1, base_y - 1)],
                          fill=color)
            else:
                d.rectangle([x0, base_y - 1, x1, base_y], fill=color)
    elif shape in ("bump4", "bump3"):
        nb = 4 if shape == "bump4" else 3
        seg = (13 - 2) / nb
        for i in range(nb):
            x0 = int(round(2 + i * seg))
            x1 = int(round(2 + (i + 1) * seg))
            if (i + skirt_variant) % 2 == 0:
                d.ellipse([x0, base_y - 2, x1, base_y + 2], fill=color)
            else:
                d.rectangle([x0, base_y - 1, x1, base_y], fill=color)
    elif shape == "wave2":
        seg = (13 - 2) / 2
        for i in range(2):
            x0 = int(round(2 + i * seg))
            x1 = int(round(2 + (i + 1) * seg))
            if (i + skirt_variant) % 2 == 0:
                d.ellipse([x0, base_y - 2, x1 + 1, base_y + 2], fill=color)
            else:
                d.rectangle([x0, base_y - 1, x1, base_y], fill=color)
    return c


def add_eyes(c, direction, body=True):
    """Add two white eyes + iris pointing `direction` ('R','U','D','L')."""
    d = ImageDraw.Draw(c)
    # eye centers
    lx, rx, ey = 5, 10, 6
    for ex in (lx, rx):
        d.ellipse([ex - 2, ey - 2, ex + 1, ey + 2], fill=WHITE)
    dx, dy = {"R": (1, 0), "U": (0, -1), "D": (0, 1), "L": (-1, 0)}[direction]
    for ex in (lx, rx):
        ix = ex + dx
        iy = ey + dy
        d.rectangle([ix - 1, iy - 1, ix, iy], fill=IRIS)
    return c


def gen_ghosts():
    img = new_sheet(128, 96)
    rows = [
        (EMBER, "spike3"),
        (ROSA,  "bump4"),
        (AQUA,  "bump3"),
        (TANGO, "wave2"),
    ]
    dir_order = ["R", "R", "U", "U", "D", "D", "L", "L"]  # mv0,mv1 per dir
    for row, (color, shape) in enumerate(rows):
        for col in range(8):
            direction = dir_order[col]
            variant = col % 2  # mv0 / mv1 skirt phase
            body = ghost_body(color, variant, variant, shape)
            add_eyes(body, direction)
            img.paste(body, (col * 16, row * 16), body)

    # row 4: frightened [blue0, blue1, white0, white1, transparent x4]
    def fright_body(body_color, variant):
        c = Image.new("RGBA", (16, 16), TRANSP)
        d = ImageDraw.Draw(c)
        d.ellipse([2, 1, 13, 12], fill=body_color)
        d.rectangle([2, 7, 13, 13], fill=body_color)
        # wavy bottom skirt
        for i in range(3):
            x0 = 2 + i * 4
            x1 = x0 + 4
            if (i + variant) % 2 == 0:
                d.ellipse([x0, 11, x1, 15], fill=body_color)
            else:
                d.rectangle([x0, 12, x1, 13], fill=body_color)
        # two small pale eyes
        for ex in (5, 10):
            d.rectangle([ex - 1, 5, ex, 7], fill=WHITE)
        # pink wavy mouth
        for i in range(4):
            mx = 4 + i * 2
            my = 10 if i % 2 == 0 else 9
            d.rectangle([mx, my, mx + 1, my], fill=ROSA)
        return c

    img.paste(fright_body(FRIGHT, 0), (0, 64))
    img.paste(fright_body(FRIGHT, 1), (16, 64))
    img.paste(fright_body(WHITE, 0), (32, 64))
    img.paste(fright_body(WHITE, 1), (48, 64))
    # cells 4-7 transparent (already)

    # row 5: eaten eyes [R,U,D,L, transparent x4] — eyes only, no body
    for col, direction in enumerate(["R", "U", "D", "L"]):
        c = Image.new("RGBA", (16, 16), TRANSP)
        add_eyes(c, direction, body=False)
        img.paste(c, (col * 16, 80), c)

    out = os.path.join(ROOT, "sprites", "ghosts.png")
    img.save(out)
    return out


# ============================================================================
# 4. pellets.png — 32x8, 8x8 cells, 4 cols x 1 row
# ============================================================================
def gen_pellets():
    img = new_sheet(32, 8)
    d = ImageDraw.Draw(img)
    # cell 0: 2x2 #FFE9B0 dot centered (cell origin x=0)
    d.rectangle([3, 3, 4, 4], fill=PELLET)
    # cell 1: 6px #FFD23F circle centered (origin x=8)
    d.ellipse([8 + 1, 1, 8 + 6, 6], fill=MUNCH)
    # cell 2: transparent (blink off) — leave empty (origin x=16)
    # cell 3: berry + leaf (origin x=24)
    bx = 24
    d.ellipse([bx + 1, 3, bx + 6, 7], fill=FRUIT)       # berry
    d.rectangle([bx + 3, 1, bx + 4, 2], fill=LEAF)      # leaf/stem
    out = os.path.join(ROOT, "pellets" if False else "sprites", "pellets.png")
    img.save(out)
    return out


# ============================================================================
# 5. Audio stubs — silent WAV (44.1kHz, mono, ~0.2s)
# ============================================================================
AUDIO_FILES = [
    "chomp_a.wav", "chomp_b.wav", "power.wav", "ghost_eat.wav",
    "death.wav", "fruit.wav", "ui_tap.wav", "extra_life.wav",
    "level_clear.wav", "ready.wav", "siren.wav",
]


def gen_audio():
    rate = 44100
    dur = 0.2
    nframes = int(rate * dur)
    silence = struct.pack("<h", 0) * nframes
    outs = []
    for name in AUDIO_FILES:
        path = os.path.join(ROOT, "audio", name)
        with wave.open(path, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(silence)
        outs.append(path)
    return outs


def main():
    made = []
    made.append(gen_maze_atlas())
    made.append(gen_muncher())
    made.append(gen_ghosts())
    made.append(gen_pellets())
    made.extend(gen_audio())
    for p in made:
        sz = os.path.getsize(p)
        print(f"{sz:>8} bytes  {p}")


if __name__ == "__main__":
    main()
