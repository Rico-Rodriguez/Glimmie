#!/usr/bin/env python3
"""Turn your own coloring pages into tabs of the coloring book.

Drop files into art/coloring/mine/, one folder per tab:

    art/coloring/mine/Cats/kitty.svg
    art/coloring/mine/Cats/sleepy cat.svg
    art/coloring/mine/Unicorns/rainbow.svg

Each folder becomes a tab (its first page is the tab's picture, folders sort by name, so
"01 Cats", "02 Unicorns" sets the order). SVG, PNG and JPG all work. The build (Actions ->
Build iPad app) runs this before building the app, so nothing generated is committed:

    pip install cairosvg pillow numpy scipy
    python3 tools/build_my_pages.py [--jobs N]

Writes into App/Resources/Games/Coloring/:
  my_<folder>_<file>.png / _t.png   line art and thumbnail (same pipeline as import_coloring.py)
  mypages.json                      the tabs, plus a hash per page so unchanged files are skipped
Pages that were removed from art/coloring/mine are removed from the output too.
"""
import hashlib, io, json, os, re, sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_coloring as ic  # noqa: E402

ROOT = ic.ROOT
MINE = os.path.join(ROOT, "art", "coloring", "mine")
OUT = ic.OUT
INDEX = os.path.join(OUT, "mypages.json")
EXTS = (".svg", ".png", ".jpg", ".jpeg")


def slug(s):
    s = re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")
    return s or "page"


def pastel(name):
    h = int(hashlib.md5(name.encode()).hexdigest()[:6], 16) / 0xFFFFFF
    import colorsys
    return [round(c, 3) for c in colorsys.hsv_to_rgb(h, 0.38, 1.0)]


def raster_ink(path, long_side=2400):
    """A PNG or JPG page: darkness 0..255, cropped to the drawing (transparent counts as paper)."""
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, "white")
    im = Image.alpha_composite(bg, im).convert("L")
    k = long_side / max(im.size)
    im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    d = 255 - np.asarray(im, dtype=np.float32)
    ys, xs = np.nonzero(d > 40)
    if len(ys) == 0:
        raise ValueError("blank picture")
    return d[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def build_one(job):
    pid, path = job
    try:
        if path.lower().endswith(".svg"):
            alpha = ic.build(path)
        else:
            orig = ic.ink_of
            ic.ink_of = lambda _p, long_side: raster_ink(path, long_side)
            try:
                alpha = ic.build(path)
            finally:
                ic.ink_of = orig
        a = Image.fromarray(alpha)
        Image.merge("LA", (Image.new("L", a.size, 0), a)).save(os.path.join(OUT, f"{pid}.png"), optimize=True)
        Image.fromarray(255 - alpha).resize((400, 300), Image.LANCZOS).save(os.path.join(OUT, f"{pid}_t.png"), optimize=True)
        return pid, None
    except Exception as e:  # a broken file shouldn't stop the other 899
        return pid, str(e)


def main():
    jobs_n = os.cpu_count() or 2
    if "--jobs" in sys.argv:
        jobs_n = int(sys.argv[sys.argv.index("--jobs") + 1])
    old = {}
    if os.path.exists(INDEX):
        with open(INDEX) as f:
            old = json.load(f).get("hashes", {})
    cats, hashes, todo, seen = [], {}, [], set()
    folders = sorted(d for d in os.listdir(MINE) if os.path.isdir(os.path.join(MINE, d))) if os.path.isdir(MINE) else []
    for folder in folders:
        files = sorted(f for f in os.listdir(os.path.join(MINE, folder)) if f.lower().endswith(EXTS))
        ids = []
        for name in files:
            base = pid = f"my_{slug(folder)}_{slug(os.path.splitext(name)[0])}"
            n = 2
            while pid in seen:
                pid = f"{base}_{n}"; n += 1
            seen.add(pid)
            path = os.path.join(MINE, folder, name)
            with open(path, "rb") as f:
                h = hashlib.sha1(f.read()).hexdigest()
            hashes[pid] = h
            ids.append(pid)
            if old.get(pid) != h or not os.path.exists(os.path.join(OUT, f"{pid}.png")):
                todo.append((pid, path))
        if ids:
            cats.append({"id": f"my_{slug(folder)}", "icon": "folder.fill", "color": pastel(folder), "pages": ids, "cover": ids[0]})
    print(f"{len(seen)} pages in {len(cats)} tabs, {len(todo)} to build")
    failed = []
    if todo:
        with ProcessPoolExecutor(max_workers=jobs_n) as ex:
            for i, (pid, err) in enumerate(ex.map(build_one, todo, chunksize=4), 1):
                if err:
                    failed.append(pid)
                    print(f"  could not build {pid}: {err}")
                elif i % 25 == 0 or i == len(todo):
                    print(f"  built {i}/{len(todo)}")
    for pid in failed:
        hashes.pop(pid, None)
        for c in cats:
            if pid in c["pages"]:
                c["pages"].remove(pid)
    cats = [c for c in cats if c["pages"]]
    for c in cats:
        c["cover"] = c["pages"][0]
    # Drop pages that were deleted or renamed.
    for name in os.listdir(OUT):
        if name.startswith("my_") and name.endswith(".png"):
            keep = name[:-4] in hashes or (name.endswith("_t.png") and name[:-6] in hashes)
            if not keep:
                os.remove(os.path.join(OUT, name))
    with open(INDEX, "w") as f:
        json.dump({"categories": cats, "hashes": hashes}, f, indent=1)


if __name__ == "__main__":
    main()
