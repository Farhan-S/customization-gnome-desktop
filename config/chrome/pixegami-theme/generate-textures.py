#!/usr/bin/env python3
"""Generate the Pixegami theme's texture tiles.

Chrome tiles theme_frame / theme_toolbar / theme_tab_background horizontally
and anchors them to the top, so those tiles need to be seamless left-to-right
only; a vertical gradient inside them is fine and gives the chrome its depth.
theme_ntp_background repeats in both directions, so that tile is seamless on
both axes.

The texture is a 45-degree hatch at roughly 2% opacity plus a trace of noise -
enough to catch the light and kill the flatness of a solid fill, not enough to
read as a pattern at a glance.

    python3 config/chrome/pixegami-theme/generate-textures.py
"""

import random
from pathlib import Path

from PIL import Image

OUT = Path(__file__).parent / "images"

MINT = (134, 255, 175)

# Value layers. Each surface sits a step lighter than the one behind it, which
# is what makes Chrome's capsule tabs and pill omnibox read as distinct shapes.
FRAME =          (8, 21, 29)     # #08151D  deepest - window frame
FRAME_INACTIVE = (10, 23, 31)    # #0A171F  unfocused window
TAB_BACKGROUND = (10, 24, 32)    # #0A1820  inactive tabs, sit on the frame
TOOLBAR =        (12, 28, 37)    # #0C1C25  toolbar + active tab
NTP =            (12, 28, 37)    # #0C1C25  new tab page

HATCH_SPACING = 8                # px between diagonal lines
HATCH_ALPHA = 6                  # out of 255
NOISE_ALPHA = 3
GRADIENT_LIFT = 10               # how much lighter the bottom edge gets


def tile(size, base, gradient=True, seamless_y=False, tint=MINT, seed=0x9E3779B9):
    """One texture tile. Seamless in x always, in y when asked."""
    w, h = size
    rng = random.Random(seed)
    img = Image.new("RGB", size)
    px = img.load()

    for y in range(h):
        # Vertical lift: the surface catches a little more light lower down,
        # which reads as depth under Chrome's rounded tab and toolbar edges.
        lift = (y / max(h - 1, 1)) * GRADIENT_LIFT if gradient else 0
        row = tuple(min(255, c + lift) for c in base)
        for x in range(w):
            r, g, b = row
            # 45-degree hatch. Using (x + y) keeps it seamless in x whenever
            # the width is a multiple of the spacing, and in y as well when
            # the height is too.
            if (x + y) % HATCH_SPACING == 0:
                a = HATCH_ALPHA / 255
                r, g, b = (c + (t - c) * a for c, t in zip((r, g, b), tint))
            n = rng.uniform(-NOISE_ALPHA, NOISE_ALPHA)
            px[x, y] = (
                max(0, min(255, int(r + n))),
                max(0, min(255, int(g + n))),
                max(0, min(255, int(b + n))),
            )

    if seamless_y and h % HATCH_SPACING:
        raise ValueError("height must be a multiple of the hatch spacing to tile in y")
    return img


def main() -> None:
    OUT.mkdir(exist_ok=True)
    made = []

    # Frame + toolbar + tabs: 64px wide (a multiple of the 8px hatch, so the
    # horizontal tiling is invisible), 128 tall to cover the tallest chrome.
    for name, base, grad in [
        ("frame", FRAME, True),
        ("frame_inactive", FRAME_INACTIVE, True),
        ("toolbar", TOOLBAR, True),
        ("tab_background", TAB_BACKGROUND, True),
    ]:
        img = tile((64, 128), base, gradient=grad)
        p = OUT / f"{name}.png"
        img.save(p, optimize=True)
        made.append(p)

    # New tab page: repeats both ways, so no gradient and a size that is a
    # multiple of the hatch spacing on both axes.
    img = tile((256, 256), NTP, gradient=False, seamless_y=True, seed=0x51ED2701)
    p = OUT / "ntp_background.png"
    img.save(p, optimize=True)
    made.append(p)

    for p in made:
        im = Image.open(p)
        print(f"  {p.name:<22} {im.size[0]:>4}x{im.size[1]:<4}  {p.stat().st_size:>6,} bytes")


if __name__ == "__main__":
    main()
