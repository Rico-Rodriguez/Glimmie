#!/usr/bin/env python3
"""Import public-domain coloring pages (Openclipart) into the coloring book.

    pip install cairosvg pillow numpy scipy
    python3 tools/import_coloring.py            # download (cached) + build everything
    python3 tools/import_coloring.py --check    # also write region previews to art/coloring/preview/
    python3 tools/import_coloring.py cat_cup    # rebuild only these page ids (or category ids)

The list of pages lives in art/coloring/imported.json:
  {"categories": [{"id", "icon" (SF Symbol), "color": [r,g,b],
                   "pages": [{"id", "src": "openclipart:<number>", "title"}]}]}
Every source is CC0 / public domain (Openclipart releases everything under CC0).
Source SVGs are cached in art/coloring/svg-cache/ (not committed).

Each page becomes, in App/Resources/Games/Coloring/:
  <id>.png     2048x1536 line art: black, with the lines in the alpha channel
  <id>_t.png   400x300 thumbnail on white, for the page picker
and pages.json lists the categories in order.

The drawing is cropped to its ink, letterboxed to 4:3 with a margin, light grey shading is
dropped, and thin lines are thickened so the app's fill (alpha >= 145 is line, at 1600x1200)
can't leak through them.
"""
import io, json, os, random, sys, urllib.request

import cairosvg
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "art", "coloring", "imported.json")
CACHE = os.path.join(ROOT, "art", "coloring", "svg-cache")
OUT = os.path.join(ROOT, "App", "Resources", "Games", "Coloring")
PREVIEW = os.path.join(ROOT, "art", "coloring", "preview")

W, H = 2048, 1536
MARGIN = 0.06
MIN_LINE = 9.0      # px at 2048 wide (~7 px at the app's 1600)
LINE_ALPHA = 145    # the app's line threshold
GAP = 10            # px at 2048: outline gaps narrower than ~2*GAP get closed


def fetch(src):
    kind, num = src.split(":")
    assert kind == "openclipart", src
    path = os.path.join(CACHE, f"{num}.svg")
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        req = urllib.request.Request(f"https://openclipart.org/download/{num}",
                                     headers={"User-Agent": "Mozilla/5.0 (Glimmie coloring import)"})
        data = urllib.request.urlopen(req, timeout=60).read()
        with open(path, "wb") as f:
            f.write(data)
    return path


def ink_of(svg_path, long_side):
    """Darkness 0..255 (255 = black), cropped to the drawing."""
    png = cairosvg.svg2png(url=svg_path, output_width=long_side, background_color="white")
    im = Image.open(io.BytesIO(png)).convert("L")
    if im.height > im.width:  # keep the long side at long_side
        png = cairosvg.svg2png(url=svg_path, output_height=long_side, background_color="white")
        im = Image.open(io.BytesIO(png)).convert("L")
    d = 255 - np.asarray(im, dtype=np.float32)
    ys, xs = np.nonzero(d > 40)
    return d[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def line_width(d):
    ink = d >= 128
    if not ink.any():
        return 0.0
    dt = ndimage.distance_transform_edt(ink)
    ridge = ink & (dt >= ndimage.maximum_filter(dt, 3) - 0.01)
    return float(np.median(dt[ridge]) * 2)


def build(svg_path):
    # Render big, then fit into the 4:3 page.
    d = ink_of(svg_path, 2400)
    box_w, box_h = W * (1 - 2 * MARGIN), H * (1 - 2 * MARGIN)
    s = min(box_w / d.shape[1], box_h / d.shape[0])
    img = Image.fromarray(np.clip(d, 0, 255).astype(np.uint8))
    img = img.resize((max(1, round(d.shape[1] * s)), max(1, round(d.shape[0] * s))), Image.LANCZOS)
    d = np.asarray(img, dtype=np.float32)
    # Drop light shading / grey fills; keep anti-aliasing on real lines.
    d = np.clip((d - 70) * 255 / (255 - 70), 0, 255)
    # Thicken thin lines.
    lw = line_width(d)
    if lw < MIN_LINE:
        r = int(round((MIN_LINE - lw) / 2))
        if r > 0:
            yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
            d = ndimage.grey_dilation(d, footprint=(xx * xx + yy * yy) <= r * r + r)
    # Bridge small gaps in outlines (a closing only adds ink where two lines nearly meet).
    yy, xx = np.mgrid[-GAP:GAP + 1, -GAP:GAP + 1]
    d = ndimage.grey_closing(d, footprint=(xx * xx + yy * yy) <= GAP * GAP)
    page = np.zeros((H, W), dtype=np.float32)
    y0, x0 = (H - d.shape[0]) // 2, (W - d.shape[1]) // 2
    page[y0:y0 + d.shape[0], x0:x0 + d.shape[1]] = d
    return page.astype(np.uint8)


def regions(alpha_1600):
    lab, n = ndimage.label(alpha_1600 < LINE_ALPHA)
    return lab, n


def leak(lab):
    """Share of the drawing's inside that the background floods into: small gaps in an outline
    are bridged by dilating the ink, and any background left inside the bridged outline leaked in."""
    small = lab[::4, ::4]
    ink = small == 0
    yy, xx = np.mgrid[-5:6, -5:6]
    fat = ndimage.binary_dilation(ink, structure=(xx * xx + yy * yy) <= 25)
    inside = ndimage.binary_fill_holes(fat) & ~fat
    bg_ids = set(np.unique(np.concatenate([small[0], small[-1], small[:, 0], small[:, -1]]))) - {0}
    bg = np.isin(small, list(bg_ids))
    return float((bg & inside).sum() / max(1, (ndimage.binary_fill_holes(fat) & ~ink).sum()))


def main():
    check = "--check" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    with open(MANIFEST) as f:
        manifest = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    catalog = {"categories": []}
    sheets, seen = [], set()
    for cat in manifest["categories"]:
        ids = []
        for p in cat["pages"]:
            pid = p["id"]
            assert pid not in seen, f"duplicate page id {pid}"
            seen.add(pid)
            ids.append(pid)
            if only and pid not in only and cat["id"] not in only:
                continue
            alpha = build(fetch(p["src"]))
            a = Image.fromarray(alpha)
            Image.merge("LA", (Image.new("L", a.size, 0), a)).save(os.path.join(OUT, f"{pid}.png"), optimize=True)
            thumb = Image.fromarray(255 - alpha).resize((400, 300), Image.LANCZOS)
            thumb.save(os.path.join(OUT, f"{pid}_t.png"), optimize=True)
            if check:
                work = np.asarray(a.resize((1600, 1200), Image.LANCZOS))
                lab, n = regions(work)
                rng = random.Random(pid)
                pal = np.array([[255, 255, 255]] + [[rng.randint(60, 255) for _ in range(3)] for _ in range(n)], dtype=np.uint8)
                rgb = pal[lab]
                rgb[lab == 0] = 0
                lk = leak(lab)
                sheets.append((f"{cat['id']}/{pid}", Image.fromarray(rgb).resize((400, 300), Image.LANCZOS), n))
                print(f"{cat['id']:10s} {pid:24s} regions={n:4d} leak={lk:.2f}{'  <-- LEAK?' if lk > 0.08 else ''}")
            else:
                print(f"{cat['id']:10s} {pid:24s}")
        catalog["categories"].append({"id": cat["id"], "icon": cat["icon"], "color": cat["color"], "pages": ids})
    if not only:
        # Remove pages that are no longer in the manifest.
        keep = {f"{i}.png" for i in seen} | {f"{i}_t.png" for i in seen} | {"pages.json"}
        for name in os.listdir(OUT):
            if name.endswith(".png") and name not in keep:
                os.remove(os.path.join(OUT, name))
        with open(os.path.join(OUT, "pages.json"), "w") as f:
            json.dump(catalog, f, indent=1)
    if check and sheets:
        from PIL import ImageDraw
        os.makedirs(PREVIEW, exist_ok=True)
        cols, per = 5, 20
        for k in range(0, len(sheets), per):
            chunk = sheets[k:k + per]
            rows = (len(chunk) + cols - 1) // cols
            sheet = Image.new("RGB", (cols * 410, rows * 330), "grey")
            dr = ImageDraw.Draw(sheet)
            for i, (name, img, n) in enumerate(chunk):
                x, y = (i % cols) * 410 + 5, (i // cols) * 330 + 5
                sheet.paste(img, (x, y))
                dr.text((x, y + 302), f"{name}  ({n})", fill="white")
            sheet.save(os.path.join(PREVIEW, f"import_{k // per + 1:02d}.jpg"), quality=85)
    total = sum(len(c["pages"]) for c in manifest["categories"])
    print(f"{total} pages in {len(manifest['categories'])} categories")


if __name__ == "__main__":
    main()
