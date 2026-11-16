#!/usr/bin/env python3
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
"""Builds the App Store iPhone Duo slides (APP_IPHONE_DUO, 2853 x 2007) in the three poses Apple asks for:
fully closed and upright, half open like a book, and fully open and upright (owner's rule, 2026-11-11).

    python3 scripts/make-duo-pose-slides.py <closed-dir> <book-dir> <open-dir> <out-dir>

Each dir holds the real captures from scripts/capture-duo.sh in that pose (sample data): closed = the outer
display (1398 x 2034), book = the inner display sideways (2853 x 2007), open = the inner display upright
(2007 x 2853). Nothing is faked: the screens are the app's own, only the device around them is drawn.
Layout: the mascot and full name, the headline and its highlights on the left; the Duo on the right, turned
slightly in 3D (the book's two pages angled at the hinge). Copy comes from store/slides.json, by screen.
"""
import importlib.util, json, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("slides", ROOT / "scripts/make-store-slides.py")
slides = importlib.util.module_from_spec(spec); spec.loader.exec_module(slides)
W, H = 2853, 2007

# Which screen in which pose: three closed, two book, two open, so every pose shows.
PLAN = [("closed", "store-02-results"), ("book", "store-04-finding"), ("open", "store-09-fix"),
        ("closed", "store-08-tracker"), ("book", "store-05-sensitive"), ("open", "store-06-checkup"),
        ("closed", "store-01-home")]


def coeffs(dst, src):
    """Perspective coefficients mapping the output quad dst onto the input quad src (PIL's convention)."""
    import numpy as np
    a = []
    for (x, y), (u, v) in zip(dst, src):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); a.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    b = np.array([c for p in src for c in p], dtype=float)
    return np.linalg.solve(np.array(a, dtype=float), b).tolist()


def warp(im, quad):
    """Draws im into the quadrilateral quad (top-left, top-right, bottom-right, bottom-left), on a canvas
    just big enough to hold it; returns the image and its offset."""
    xs, ys = [p[0] for p in quad], [p[1] for p in quad]
    x0, y0 = int(min(xs)), int(min(ys))
    size = (int(max(xs)) - x0 + 1, int(max(ys)) - y0 + 1)
    local = [(x - x0, y - y0) for x, y in quad]
    src = [(0, 0), (im.width, 0), (im.width, im.height), (0, im.height)]
    out = im.transform(size, Image.PERSPECTIVE, coeffs(local, src), Image.BICUBIC)
    return out, (x0, y0)


def framed(screen, radius, bezel):
    """The screen in a slim near-black body with rounded corners, as RGBA."""
    s = screen.convert("RGBA")
    body = Image.new("RGBA", (s.width + 2 * bezel, s.height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(body).rounded_rectangle((0, 0, body.width - 1, body.height - 1), radius + bezel, fill=(14, 14, 16, 255),
                                           outline=(70, 66, 50, 255), width=3)
    mask = Image.new("L", s.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, s.width - 1, s.height - 1), radius, fill=255)
    body.paste(s, (bezel, bezel), mask)
    return body


def shadow(canvas, quad, blur):
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + 30, y + 40) for x, y in quad], fill=(0, 0, 0, 200))
    canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)))


def upright(canvas, shot, box_h, cx, cy, crease=False):
    """One upright device, turned about 14 degrees: its far (right) edge a little shorter and nearer."""
    body = framed(shot, 70, 22)
    if crease:   # the fold across the open Duo, a faint line at half height
        d = ImageDraw.Draw(body)
        d.line((22, body.height // 2, body.width - 22, body.height // 2), fill=(255, 255, 255, 40), width=3)
    scale = box_h / body.height
    w, h = body.width * scale, box_h
    squeeze, drop = 0.97, h * 0.045
    x0, x1 = cx - w / 2, cx - w / 2 + w * squeeze
    quad = [(x0, cy - h / 2), (x1, cy - h / 2 + drop), (x1, cy + h / 2 - drop), (x0, cy + h / 2)]
    shadow(canvas, quad, 50)
    img, off = warp(body, quad)
    canvas.alpha_composite(img, off)


def book(canvas, shot, page_w, cx, cy):
    """The open Duo held like a book facing you: its two pages split at the fold, the hinge furthest away,
    so the hinge edge is the shorter one and the outer edges come towards you."""
    body = framed(shot, 60, 20)
    half = body.width // 2
    left, right = body.crop((0, 0, half, body.height)), body.crop((half, 0, body.width, body.height))
    scale = page_w / half
    h = body.height * scale
    # Held like a book facing you: the hinge is the far edge (shorter), the outer edges come towards you
    # (full height), and each page is foreshortened across its width (owner, 2026-11-16: not the other way).
    pull, drop = page_w * 0.09, h * 0.06
    lq = [(cx - page_w + pull, cy - h / 2), (cx, cy - h / 2 + drop), (cx, cy + h / 2 - drop), (cx - page_w + pull, cy + h / 2)]
    rq = [(cx, cy - h / 2 + drop), (cx + page_w - pull, cy - h / 2), (cx + page_w - pull, cy + h / 2), (cx, cy + h / 2 - drop)]
    shadow(canvas, [lq[0], rq[1], rq[2], lq[3]], 60)
    for page, quad, shade in ((left, lq, 0.86), (right, rq, 1.0)):
        if shade < 1:   # the left page faces a little away from the light
            dark = Image.new("RGBA", page.size, (0, 0, 0, int(255 * (1 - shade))))
            page = Image.alpha_composite(page, Image.composite(dark, Image.new("RGBA", page.size, (0, 0, 0, 0)), page.getchannel("A")))
        img, off = warp(page, quad)
        canvas.alpha_composite(img, off)
    ImageDraw.Draw(canvas).line((cx, cy - h / 2 + drop + 6, cx, cy + h / 2 - drop - 6), fill=(8, 8, 9, 255), width=8)   # the hinge


def make(pose, screen, spec, dirs, mascot):
    c = slides.glow_background(W, H).convert("RGBA")
    d = ImageDraw.Draw(c)
    left = 150
    m = mascot.resize((140, int(140 * mascot.height / mascot.width)), Image.LANCZOS)
    c.alpha_composite(m, (left, 120))
    f = slides.font(58, "Semibold")
    nx, ny = left + m.width + 28, 120 + m.height // 2 - 38
    d.text((nx, ny), "hYYa", font=f, fill=slides.SAND)
    d.text((nx + d.textlength("hYYa ", font=f), ny), "Digital Footprint Check", font=f, fill=slides.INK)
    d.rounded_rectangle((nx, ny + 82, nx + 68, ny + 88), 3, fill=slides.SAND)
    col = 1080
    y = slides.draw_headline(d, spec["headline"], left, 120 + m.height + 120, col, 118)
    slides.chips(d, spec["highlights"], left, y + 70, col, 46)
    shot = Image.open(dirs[pose] / f"{screen}.png")
    if pose == "book":
        book(c, shot, 760, 1300 + (W - 1300) // 2, H // 2 + 60)
    else:
        upright(c, shot, 1700, 1300 + (W - 1300) // 2, H // 2 + 40, crease=pose == "open")
    return c.convert("RGB")


if __name__ == "__main__":
    closed, bookd, opend, out = (Path(p) for p in sys.argv[1:5])
    out.mkdir(parents=True, exist_ok=True)
    specs = {s["screen"]: s for s in json.loads((ROOT / "store/slides.json").read_text())["slides"]}
    specs.setdefault("store-09-fix", next(s for s in specs.values() if "step by step" in s["headline"]))
    mascot = Image.open(slides.MASCOT).convert("RGBA")
    dirs = {"closed": closed, "book": bookd, "open": opend}
    for i, (pose, screen) in enumerate(PLAN, 1):
        path = out / f"{i:02d}-{pose}-{screen.split('-', 2)[-1]}.png"
        make(pose, screen, specs[screen], dirs, mascot).save(path, optimize=True)
        print(path)
