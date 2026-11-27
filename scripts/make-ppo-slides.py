#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Builds slide 1 of the App Store product page test versions (PPO) in the Midnight Library look, for the
device classes of the default page that product page tests support (iPhone 6.9", iPad 13", iPhone Duo; Apple's
tests cover iOS and iPadOS only, so no Mac).

    python3 scripts/make-ppo-slides.py <raw-iphone> <raw-ipad> <raw-duo> <out-dir>

Each raw dir holds ppo-b-rise.png from StoreScreenshotsUITests.testCapturePPORise (sample data; the Duo's is the
folded outer display). The ideas are Marketing's 2026-11 plan, unchanged; only the look is new:
  A  "What do your apps know about you?": six things an app can learn, as flat slate cards with a coral edge, the
     mascot under a gold spotlight, "Find out in one tap. Then fix it." No app screen.
  B  "Fix it. Watch your score go up.": 45 -> 57 in big type over the real Footprint page after a fix
     (the made-up earlier scan of -previewRise).
Slides 2-7 of each test version are the default page's own, so only slide 1 differs.
"""
import importlib.util, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
_s = importlib.util.spec_from_file_location("slides", ROOT / "scripts/make-store-slides.py")
S = importlib.util.module_from_spec(_s); _s.loader.exec_module(S)
_d = importlib.util.spec_from_file_location("duo", ROOT / "scripts/make-duo-pose-slides.py")
D = importlib.util.module_from_spec(_d); _d.loader.exec_module(D)

CORAL = (229, 115, 115)       # "worth a look"
SAGE = (129, 199, 132)        # fixed / better
EDGE = (255, 255, 255, 13)    # the cards' 1pt white 5% edge
A_HEAD = "What do your apps *know\u00a0about\u00a0you?*"   # no-break spaces: the gold phrase stays on one line
A_CARDS = [("Your dating life", "from your dating apps"), ("A unique fingerprint", "links you across apps"),
           ("Your first name", "from your headphones' name"), ("Your money", "crypto and betting apps"),
           ("Your health", "period, fertility, therapy apps"), ("Where you've been", "with Photos access")]
A_FOOT = "Find out in one tap. Then fix it."
A_SUB = ["Open source", "Nothing leaves your device"]   # no price words on screenshots
B_HEAD = "Fix it. Watch your score *go\u00a0up.*"


def card(canvas, box, title, sub, unit, tsize, ssize):
    """A flat slate card: 1pt white 5% edge, a 3pt coral line down its leading edge, no shadow."""
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = int(22 * unit)
    d.rounded_rectangle(box, r, fill=S.CARD + (255,), outline=EDGE, width=max(2, int(3 * unit)))
    canvas.alpha_composite(layer)
    d = ImageDraw.Draw(canvas)
    line = max(6, int(9 * unit))
    d.rounded_rectangle((x0 + int(4 * unit), y0 + r, x0 + int(4 * unit) + line, y1 - r), line // 2, fill=CORAL)
    tx = x0 + int(44 * unit)
    ft, fs = S.font(tsize, "Semibold"), S.font(ssize, "Regular")
    gap = int(tsize * 0.32)
    th = tsize + gap + ssize
    ty = (y0 + y1) / 2 - th / 2 - tsize * 0.12
    d.text((tx, ty), title, font=ft, fill=S.INK)
    d.text((tx, ty + tsize + gap), sub, font=fs, fill=S.MUTED)


def spotlight_mascot(canvas, mascot, width, cx, top):
    """The cut-out mascot standing in a soft gold spotlight."""
    m = mascot.resize((width, int(width * mascot.height / mascot.width)), Image.LANCZOS)
    # The canvas is wide enough that the blur fades to nothing before its edge (no hard rim).
    glow = Image.new("RGBA", (int(width * 2.6), int(width * 2.4)), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((glow.width * 0.28, glow.height * 0.3, glow.width * 0.72, glow.height * 0.7), fill=S.SAND + (70,))
    glow = glow.filter(ImageFilter.GaussianBlur(width * 0.18))
    canvas.alpha_composite(glow, (int(cx - glow.width / 2), int(top + m.height * 0.55 - glow.height / 2)))
    canvas.alpha_composite(m, (int(cx - m.width / 2), int(top)))
    return top + m.height


def width_of(d, text, size, weight):
    return d.textlength(text, font=S.font(size, weight))


def numbers(d, cx, y, size, max_w=None):
    """45 (muted) -> (gold) 57 (sage), centred on cx; shrinks to fit max_w."""
    parts = [("45", S.MUTED), ("  →  ", S.SAND), ("57", SAGE)]
    while True:
        f = S.font(size, "Bold")
        w = sum(d.textlength(t, font=f) for t, _ in parts)
        if max_w is None or w <= max_w or size < 60:
            break
        size -= 4
    x = cx - w / 2
    for t, c in parts:
        d.text((x, y), t, font=f, fill=c)
        x += d.textlength(t, font=f)
    return y + int(size * 1.05)


# ---- portrait: iPhone 6.9" and iPad 13" -------------------------------------------------------------------------

def portrait_a(w, h, mascot):
    c = S.glow_background(w, h).convert("RGBA")
    d = ImageDraw.Draw(c)
    unit = w / 1320
    tablet = w / h > 0.6
    y = S.name_lockup(c, d, mascot, w / 2, int(90 * unit), int((40 if tablet else 50) * unit))
    y = S.centred_lines(d, S.headline_parts(A_HEAD), y + int(50 * unit), w * 0.88, int((96 if tablet else 112) * unit), "Bold", w, 1.1)
    # Six cards in two columns.
    cols, gap = 2, int((34 if tablet else 30) * unit)
    grid_w = w * (0.80 if tablet else 0.90)
    cw = (grid_w - gap) / cols
    ch = int((150 if tablet else 190) * unit)
    x0 = (w - grid_w) / 2
    top = y + int(60 * unit)
    tsize, ssize = int((44 if tablet else 50) * unit), int((32 if tablet else 36) * unit)
    for i, (t, s) in enumerate(A_CARDS):
        r, k = divmod(i, cols)
        bx = x0 + k * (cw + gap)
        by = top + r * (ch + gap)
        card(c, (int(bx), int(by), int(bx + cw), int(by + ch)), t, s, unit, tsize, ssize)
    cards_end = top + 3 * ch + 2 * gap
    # Footer, then the mascot fills the room between.
    fsize, ssz = int((64 if tablet else 66) * unit), int((40 if tablet else 42) * unit)
    foot_y = h - int(90 * unit) - ssz - int(26 * unit) - fsize
    room = foot_y - int(50 * unit) - (cards_end + int(50 * unit))
    mw = min(int(w * (0.42 if tablet else 0.62)), int(room * mascot.width / mascot.height))
    mh = int(mw * mascot.height / mascot.width)
    spotlight_mascot(c, mascot, mw, w / 2, cards_end + int(50 * unit) + (room - mh) / 2)
    y = S.centred_lines(d, [(A_FOOT, S.INK)], foot_y, w * 0.9, fsize, "Bold", w, 1.1)
    S.centred_lines(d, S.highlight_parts(A_SUB), y + int(26 * unit), w * 0.9, ssz, "Regular", w, 1.3, break_at={S.DOT})
    return c.convert("RGB")


def portrait_b(w, h, mascot, shot):
    c = S.glow_background(w, h).convert("RGBA")
    d = ImageDraw.Draw(c)
    unit = w / 1320
    tablet = w / h > 0.6
    y = S.name_lockup(c, d, mascot, w / 2, int(90 * unit), int((40 if tablet else 50) * unit))
    y = S.centred_lines(d, S.headline_parts(B_HEAD), y + int(50 * unit), w * 0.88, int((96 if tablet else 112) * unit), "Bold", w, 1.1)
    y = numbers(d, w / 2, y + int(30 * unit), int((150 if tablet else 190) * unit))
    dev_y = y + int(60 * unit)
    fit_w = int((h - dev_y - 70 * unit) * shot.width / shot.height)
    dev_w = int(w * 0.74) if tablet else min(int(w * 0.68), fit_w)   # tablets run off the bottom, as on the default page
    frame = S.device(shot, dev_w)
    dev_x = (w - frame.width) // 2
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((dev_x + 20, dev_y + 40, dev_x + frame.width + 20, dev_y + frame.height + 40), 80, fill=(0, 0, 0, 200))
    c.alpha_composite(sh.filter(ImageFilter.GaussianBlur(40)))
    c.alpha_composite(frame, (dev_x, dev_y))
    edge = int(16 * unit)
    big_w = min(int(w * (0.16 if tablet else 0.22)), int((dev_x - edge) / 0.82))
    big = mascot.resize((big_w, int(big_w * mascot.height / mascot.width)), Image.LANCZOS)
    c.alpha_composite(big, (max(edge, dev_x - int(big_w * 0.82)), h - big.height - int(30 * unit)))
    return c.convert("RGB")


# ---- iPhone Duo, 2853 x 2007 --------------------------------------------------------------------------------------

def duo_header(c, d, mascot, head, sub_parts=None):
    W = D.W
    m = mascot.resize((120, int(120 * mascot.height / mascot.width)), Image.LANCZOS)
    f = S.font(54, "Semibold")
    name_w = d.textlength("hYYa Digital Footprint Check", font=f)
    x0 = (W - (m.width + 24 + name_w)) / 2
    c.alpha_composite(m, (int(x0), 70))
    ny = 70 + m.height // 2 - 34
    d.text((x0 + m.width + 24, ny), "hYYa", font=f, fill=S.SAND)
    d.text((x0 + m.width + 24 + d.textlength("hYYa ", font=f), ny), "Digital Footprint Check", font=f, fill=S.INK)
    D.centred_line(d, S.headline_parts(head), 260, W - 300, 150, "Bold")


def duo_a(mascot):
    W, H = D.W, D.H
    c = S.glow_background(W, H).convert("RGBA")
    d = ImageDraw.Draw(c)
    duo_header(c, d, mascot, A_HEAD)
    # Three cards each side of the mascot.
    cw, ch, gap = 820, 220, 44
    top = 560
    for i, (t, s) in enumerate(A_CARDS):
        side, r = i % 2, i // 2
        bx = 150 if side == 0 else W - 150 - cw
        by = top + r * (ch + gap)
        card(c, (bx, by, bx + cw, by + ch), t, s, 2.0, 66, 46)
    cards_end = top + 3 * ch + 2 * gap
    mw = 760
    spotlight_mascot(c, mascot, mw, W / 2, 540)
    D.centred_line(d, [(A_FOOT, S.INK)], 1520, W - 400, 100, "Bold")
    D.centred_line(d, S.highlight_parts(A_SUB), 1680, W - 400, 64, "Regular")
    return c.convert("RGB")


def duo_b(mascot, shot):
    W, H = D.W, D.H
    c = S.glow_background(W, H).convert("RGBA")
    d = ImageDraw.Draw(c)
    duo_header(c, d, mascot, B_HEAD)
    # The closed Duo upright, as on the default page's slide 1; the big numbers beside it, the mascot on the other side.
    D.upright(c, shot, 1380, W // 2, 1275)
    # Centred in the room right of the device (its right edge is about x 1880), never past the slide's edge.
    ncx = (1900 + W - 90) / 2
    numbers(d, ncx, 1080, 200, max_w=W - 90 - 1900)
    lbl = S.font(52, "Regular")
    t = "after two fixes"
    d.text((ncx - d.textlength(t, font=lbl) / 2, 1320), t, font=lbl, fill=S.MUTED)
    big = mascot.resize((560, int(560 * mascot.height / mascot.width)), Image.LANCZOS)
    c.alpha_composite(big, (W // 2 - 560 - 520, H - big.height - 60))
    return c.convert("RGB")


if __name__ == "__main__":
    raw_iphone, raw_ipad, raw_duo, out = (Path(p) for p in sys.argv[1:5])
    mascot = Image.open(S.MASCOT).convert("RGBA")
    jobs = [("iphone-6.9", 1320, 2868, raw_iphone), ("ipad-13", 2064, 2752, raw_ipad)]
    for name, w, h, raw in jobs:
        (out / "A" / name).mkdir(parents=True, exist_ok=True); (out / "B" / name).mkdir(parents=True, exist_ok=True)
        portrait_a(w, h, mascot).save(out / "A" / name / "01-ppo-a.png", optimize=True)
        portrait_b(w, h, mascot, Image.open(raw / "ppo-b-rise.png")).save(out / "B" / name / "01-ppo-b.png", optimize=True)
    for v in "AB":
        (out / v / "duo").mkdir(parents=True, exist_ok=True)
    duo_a(mascot).save(out / "A" / "duo" / "01-ppo-a.png", optimize=True)
    duo_b(mascot, Image.open(raw_duo / "ppo-b-rise.png")).save(out / "B" / "duo" / "01-ppo-b.png", optimize=True)
    for p in sorted(out.rglob("01-ppo-*.png")):
        print(p, Image.open(p).size)
