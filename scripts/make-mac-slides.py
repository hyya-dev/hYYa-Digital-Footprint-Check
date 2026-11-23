#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Builds the Mac App Store slides (2880 x 1800) from raw window captures.

    python3 scripts/make-mac-slides.py <raw-dir> <out-dir>

Raw captures come from the Mac app launched with -sampleData (made-up name, serial number and
apps), so no real Mac's details reach a public image. Layout: the mascot and full name, headline
and highlights on the left; the real app window on the right, running off the right edge.
Shares fonts and colours with scripts/make-store-slides.py.
"""
import importlib.util, json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("slides", ROOT / "scripts/make-store-slides.py")
slides = importlib.util.module_from_spec(spec); spec.loader.exec_module(slides)
W, H = 2880, 1800


def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0)); out.paste(im, (0, 0), mask); return out


def make(spec_slide, raw, mascot):
    """Owner, 2026-11-23 (hYYa Encrypted Notes' slides as the model; same layout as the Duo set): the name centred at
    the top, one big centred headline, the highlights as one line under it, the real window large and centred
    running off the bottom, the mascot standing beside it."""
    c = slides.glow_background(W, H).convert("RGBA")
    d = ImageDraw.Draw(c)
    y = slides.name_lockup(c, d, mascot, W / 2, 70, 54)
    y = slides.centred_lines(d, slides.headline_parts(spec_slide["headline"]), y + 60, W - 300, 140, "Bold", W, 1.1)
    y = slides.centred_lines(d, slides.highlight_parts(spec_slide["highlights"]), y + 20, W - 400, 60, "Regular", W, 1.3,
                             break_at={slides.DOT})
    win = Image.open(raw / f"{spec_slide['screen']}.png").convert("RGB")
    ww = 1900
    win = win.resize((ww, int(win.height * ww / win.width)), Image.LANCZOS)
    win = rounded(win, 26)
    x, wy = (W - ww) // 2, y + 70
    shadow = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x + 20, wy + 40, x + win.width + 20, wy + win.height + 40), 30, fill=(0, 0, 0, 220))
    c.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(45)))
    ImageDraw.Draw(c).rounded_rectangle((x - 2, wy - 2, x + win.width + 1, wy + win.height + 1), 28, outline=slides.SAND_DEEP + (255,), width=2)
    c.alpha_composite(win, (x, wy))
    big = mascot.resize((400, int(400 * mascot.height / mascot.width)), Image.LANCZOS)
    c.alpha_composite(big, (50, H - big.height - 50))
    return c.convert("RGB")


if __name__ == "__main__":
    raw, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    data = json.loads((ROOT / "store/slides-mac.json").read_text())
    mascot = Image.open(slides.MASCOT).convert("RGBA")
    for i, s in enumerate(data["slides"], 1):
        path = out / f"{i:02d}-{s['screen'].split('-', 2)[-1]}.png"
        make(s, raw, mascot).save(path, optimize=True)
        print(path)
