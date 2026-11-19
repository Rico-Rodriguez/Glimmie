#!/usr/bin/env python3
"""Build the coloring pages: art/coloring/*.py -> App/Resources/Games/Coloring/*.png + pages.json.

    pip install cairosvg pillow numpy scipy
    python3 tools/make_coloring.py            # build everything
    python3 tools/make_coloring.py --check    # also write preview sheets to art/coloring/preview/

Each page becomes:
  <id>.png     2048x1536 line art: black, with the lines in the alpha channel
  <id>_t.png   400x300 thumbnail on white, for the page picker
The check fills every region with a random color at the app's working size (1600x1200),
so leaks (two areas that should be separate but share a gap) are easy to spot.
"""
import io, json, os, random, sys

import cairosvg
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "art", "coloring"))
import pages  # noqa: E402
from lib import W, H  # noqa: E402

OUT = os.path.join(ROOT, "App", "Resources", "Games", "Coloring")
PREVIEW = os.path.join(ROOT, "art", "coloring", "preview")


def svg_doc(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">'
            f'<rect width="{W}" height="{H}" fill="white"/>{body}</svg>')


def render(body, w):
    png = cairosvg.svg2png(bytestring=svg_doc(body).encode(), output_width=w, output_height=w * H // W)
    return Image.open(io.BytesIO(png)).convert("L")


def regions(gray):
    """Same rule as the app: a pixel is line when it is darker than mid-grey."""
    a = np.asarray(gray)
    free = a > 110
    lab, n = ndimage.label(free)
    return lab, n


def main():
    check = "--check" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    catalog = {"categories": []}
    sheets = []
    for cat in pages.CATEGORIES:
        ids = []
        for pid, fn in cat["pages"]:
            ids.append(pid)
            if only and pid not in only and cat["id"] not in only:
                continue
            body = fn()
            big = render(body, 2048)
            alpha = Image.eval(big, lambda v: 255 - v)
            la = Image.merge("LA", (Image.new("L", big.size, 0), alpha))
            la.save(os.path.join(OUT, f"{pid}.png"), optimize=True)
            thumb = render(body, 400)
            thumb.save(os.path.join(OUT, f"{pid}_t.png"), optimize=True)
            if check:
                work = render(body, 1600)
                lab, n = regions(work)
                sizes = np.bincount(lab.ravel())
                tiny = int(((sizes[1:] > 0) & (sizes[1:] < 150)).sum())
                rng = random.Random(pid)
                pal = np.array([[255, 255, 255]] + [[rng.randint(60, 255) for _ in range(3)] for _ in range(n)], dtype=np.uint8)
                rgb = pal[lab]
                rgb[lab == 0] = 0
                img = Image.fromarray(rgb).resize((480, 360), Image.LANCZOS)
                sheets.append((pid, img, n, tiny))
                print(f"{pid:22s} regions={n:4d} tiny={tiny}")
        catalog["categories"].append({"id": cat["id"], "icon": cat["icon"], "color": cat["color"], "pages": ids})
    if not only:
        with open(os.path.join(OUT, "pages.json"), "w") as f:
            json.dump(catalog, f, indent=1)
    if check and sheets:
        os.makedirs(PREVIEW, exist_ok=True)
        cols = 4
        for k in range(0, len(sheets), 12):
            chunk = sheets[k:k + 12]
            rows = (len(chunk) + cols - 1) // cols
            sheet = Image.new("RGB", (cols * 490, rows * 370), "grey")
            for i, (pid, img, n, tiny) in enumerate(chunk):
                sheet.paste(img, ((i % cols) * 490 + 5, (i // cols) * 370 + 5))
            sheet.save(os.path.join(PREVIEW, f"sheet_{k // 12 + 1}.jpg"), quality=85)
    total = sum(len(c["pages"]) for c in pages.CATEGORIES)
    print(f"{total} pages in {len(pages.CATEGORIES)} categories")


if __name__ == "__main__":
    main()
