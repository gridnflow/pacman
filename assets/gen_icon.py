#!/usr/bin/env python3
"""Generate the Chompire app launcher icon master + Android adaptive layers.

Original art only (no trademarked Pac-Man shape/look). The "Muncher" here is an
ORIGINAL gold chomper: a slightly squashed disc with a softer wedge mouth, a
lower-right shade band for volume, a 1px neon-blue rim accent, and a corner
maze-elbow motif (neon blue) plus a trail of cream pellets the chomper is about
to eat. Designed to read at small launcher sizes: single bold subject, high
contrast on near-black indigo.

Outputs (all under assets/icon/):
  app_icon.png            1024x1024  full master (bg + Muncher + pellets + maze accent)
  app_icon_foreground.png 1024x1024  transparent; Muncher+pellets inside ~66% safe area
  app_icon_maskable.png   1024x1024  transparent; Muncher only, tighter ~58% safe area

Technique: draw at 4x (SS=4) then downscale with LANCZOS for clean anti-aliasing,
mirroring the spirit of assets/gen_placeholder.py (reproducible, deps = Pillow).

Run:  python3 assets/gen_icon.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "icon")

SIZE = 1024          # final master size
SS = 4               # supersample factor
S = SIZE * SS        # working canvas size

# ---- Palette (docs/style-guide.md) -----------------------------------------
BG_DEEP   = (11, 11, 26, 255)     # #0B0B1A  bg.deep
MUNCH     = (255, 210, 63, 255)   # #FFD23F  muncher.body
SHADE     = (224, 162, 30, 255)   # #E0A21E  muncher.shade
WALL_EDGE = (59, 107, 255, 255)   # #3B6BFF  wall.edge (neon blue)
PELLET    = (255, 233, 176, 255)  # #FFE9B0  pellet
POWER     = (255, 210, 63, 255)   # #FFD23F  power
TRANSP    = (0, 0, 0, 0)


def _muncher_layer(cx, cy, r, mouth_half=38.0):
    """Render a Muncher onto its own transparent RGBA layer (full canvas)."""
    layer = Image.new("RGBA", (S, S), TRANSP)
    d = ImageDraw.Draw(layer)
    bbox = [cx - r, cy - r, cx + r, cy + r]
    rim = int(round(r * 0.045))

    # rim halo + body
    d.ellipse([cx - r - rim, cy - r - rim, cx + r + rim, cy + r + rim],
              fill=WALL_EDGE)
    d.ellipse(bbox, fill=MUNCH)

    # Volume: paint a SHADE-coloured disc over the whole body, then lay a gold
    # disc offset UP-LEFT on top. Only the thin lower-right crescent between the
    # two stays shaded -> a subtle 3D pop (per style-guide: 1px lower-right shade).
    body_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body_mask).ellipse(bbox, fill=255)

    shade = Image.new("RGBA", (S, S), TRANSP)
    ImageDraw.Draw(shade).ellipse(bbox, fill=SHADE)
    layer = Image.composite(shade, layer, body_mask)

    off = int(round(r * 0.085))   # how thick the lower-right shade band reads
    hi = Image.new("RGBA", (S, S), TRANSP)
    ImageDraw.Draw(hi).ellipse(
        [cx - r - off, cy - r - off, cx + r - off, cy + r - off], fill=MUNCH)
    hi_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hi_mask).ellipse(
        [cx - r - off, cy - r - off, cx + r - off, cy + r - off], fill=255)
    # clip the highlight to the body so it can't spill past the rim
    hi_mask = Image.composite(hi_mask, Image.new("L", (S, S), 0), body_mask)
    layer = Image.composite(hi, layer, hi_mask)

    # mouth wedge -> truly erase those pixels (ImageDraw with TRANSP fill only
    # alpha-blends, it doesn't clear). Build a wedge mask and zero the alpha
    # everywhere the wedge covers.
    wr = r + rim + int(round(r * 0.02)) + 4
    wedge = Image.new("L", (S, S), 0)
    ImageDraw.Draw(wedge).pieslice(
        [cx - wr, cy - wr, cx + wr, cy + wr],
        -mouth_half, mouth_half, fill=255)
    cur_alpha = layer.split()[3]
    keep = Image.new("L", (S, S), 0)
    # keep alpha where wedge is NOT set
    new_alpha = Image.composite(keep, cur_alpha, wedge)
    layer.putalpha(new_alpha)
    return layer


def _pellets_layer(cx, cy, r, mouth_half=38.0):
    """A trail of 3 cream pellets in front of the mouth (to the right),
    increasing in size toward the chomper, plus one amber power pellet."""
    # pellets march along +x starting just past the mouth opening
    start = cx + r * 1.18
    gap = r * 0.40
    sizes = [r * 0.105, r * 0.135, r * 0.175]   # far -> near (near is biggest)
    xs = [start + gap * 2, start + gap, start]

    # soft glow: solid dots blurred on their own layer, then the crisp dots on top
    glow = Image.new("RGBA", (S, S), TRANSP)
    gd = ImageDraw.Draw(glow)
    for x, pr in zip(xs, sizes):
        gd.ellipse([x - pr, cy - pr, x + pr, cy + pr],
                   fill=(255, 233, 176, 200))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=r * 0.10))

    layer = glow
    d = ImageDraw.Draw(layer)
    for x, pr in zip(xs, sizes):
        d.ellipse([x - pr, cy - pr, x + pr, cy + pr], fill=PELLET)
    return layer


def _maze_accent_layer():
    """Neon-blue maze elbow motifs in two opposite corners (top-left,
    bottom-right) — rounded-corner strokes echoing wall.edge, kept subtle and
    out of the central subject zone."""
    layer = Image.new("RGBA", (S, S), TRANSP)
    d = ImageDraw.Draw(layer)
    lw = int(round(S * 0.022))           # stroke width
    margin = int(round(S * 0.085))
    arm = int(round(S * 0.20))           # length of each elbow arm
    rad = int(round(S * 0.06))           # corner rounding

    def elbow(corner):
        if corner == "tl":
            ox, oy = margin, margin
            # horizontal arm going right, vertical arm going down, joined by an
            # arc at (ox+rad, oy+rad)
            d.line([ox + rad, oy, ox + rad + arm, oy], fill=WALL_EDGE, width=lw)
            d.line([ox, oy + rad, ox, oy + rad + arm], fill=WALL_EDGE, width=lw)
            d.arc([ox, oy, ox + 2 * rad, oy + 2 * rad], 180, 270,
                  fill=WALL_EDGE, width=lw)
        else:  # br
            ox, oy = S - margin, S - margin
            d.line([ox - rad, oy, ox - rad - arm, oy], fill=WALL_EDGE, width=lw)
            d.line([ox, oy - rad, ox, oy - rad - arm], fill=WALL_EDGE, width=lw)
            d.arc([ox - 2 * rad, oy - 2 * rad, ox, oy], 0, 90,
                  fill=WALL_EDGE, width=lw)

    elbow("tl")
    elbow("br")
    # round the line caps a touch by overlaying small dots at arm ends
    return layer


def _rounded_bg():
    """Solid deep-indigo full-bleed background (square; launchers apply their own
    rounding/masking)."""
    return Image.new("RGBA", (S, S), BG_DEEP)


def build_master():
    img = _rounded_bg()

    # maze accent (subtle, behind subject)
    accent = _maze_accent_layer()
    # dim the accent so it doesn't fight the chomper
    accent = Image.eval(accent, lambda v: v)  # keep; alpha already in WALL_EDGE
    aa = accent.split()[3].point(lambda v: int(v * 0.55))
    accent.putalpha(aa)
    img = Image.alpha_composite(img, accent)

    # Muncher: nudged left so the pellet trail balances it and all 3 pellets fit.
    cx = int(S * 0.41)
    cy = int(S * 0.52)
    r = int(S * 0.29)
    mouth = 40.0

    pellets = _pellets_layer(cx, cy, r, mouth)
    img = Image.alpha_composite(img, pellets)

    muncher = _muncher_layer(cx, cy, r, mouth)
    # soft glow under the muncher
    glow = muncher.filter(ImageFilter.GaussianBlur(radius=S * 0.012))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, muncher)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def build_foreground():
    """Transparent layer: Muncher + pellets only, inside the adaptive-icon 66%
    safe area (centre 2/3). No background fill."""
    layer = Image.new("RGBA", (S, S), TRANSP)
    cx = int(S * 0.46)
    cy = int(S * 0.50)
    r = int(S * 0.215)          # keep within centre 66% safe zone
    mouth = 40.0
    layer = Image.alpha_composite(layer, _pellets_layer(cx, cy, r, mouth))
    layer = Image.alpha_composite(layer, _muncher_layer(cx, cy, r, mouth))
    return layer.resize((SIZE, SIZE), Image.LANCZOS)


def build_maskable():
    """Transparent layer, Muncher only, tighter ~58% safe area for aggressive
    circular/squircle masks."""
    layer = Image.new("RGBA", (S, S), TRANSP)
    cx = int(S * 0.50)
    cy = int(S * 0.50)
    r = int(S * 0.205)
    mouth = 40.0
    layer = Image.alpha_composite(layer, _muncher_layer(cx, cy, r, mouth))
    return layer.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    outputs = []

    master = build_master()
    p = os.path.join(OUT_DIR, "app_icon.png")
    master.save(p)
    outputs.append(p)

    fg = build_foreground()
    p = os.path.join(OUT_DIR, "app_icon_foreground.png")
    fg.save(p)
    outputs.append(p)

    mask = build_maskable()
    p = os.path.join(OUT_DIR, "app_icon_maskable.png")
    mask.save(p)
    outputs.append(p)

    # verify
    for path in outputs:
        with Image.open(path) as im:
            print(f"{os.path.relpath(path, ROOT)}: {im.size[0]}x{im.size[1]} "
                  f"{im.mode}  {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
