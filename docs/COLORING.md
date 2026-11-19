# Coloring (game in the drawer)

An original coloring book for a pre-reader. No ads, no purchases, nothing locked, no voice.

## What she can do
- **Book:** 59 pages in 10 categories (animals, magic, princess, ocean, treats, garden, dinos,
  things that go, space, holidays) plus a blank sheet. Category tabs are icons, not words.
- **Tap to fill** any area, in 8 styles: solid, glitter, stripes, dots, hearts, stars, rainbow, ombre.
- **Brushes:** marker, crayon (paper grain), glitter pen, rainbow pen, heart/star stamps, eraser,
  in 3 sizes. "Stay inside the lines" is on by default (the button next to the sizes turns it off).
- **24 colors**, **72 stickers** (drag, pinch, twist, or the bigger/smaller/turn/trash buttons).
- **Undo** (12 steps) and **clear** (asks first, with big ✓/✗ icons).
- **Gallery:** every page she works on is saved automatically. ✓ in the studio saves with confetti and
  opens the gallery. From the gallery she can keep coloring a picture; a grown-up can save it to
  Photos or delete it (asks first).

## How it works
- Pages are drawn in code: `art/coloring/lib.py` (shapes) and `art/coloring/pages_*.py` (one function per page).
  `python3 tools/make_coloring.py` renders them to `App/Resources/Games/Coloring/` (`<id>.png` line art in the
  alpha channel at 2048x1536, `<id>_t.png` thumbnails, `pages.json`). `--check` writes region previews to
  `art/coloring/preview/` (each closed area in a random color) to catch leaks.
- In the app (`App/Sources/Games/Coloring/`) the line art is drawn over a 1600x1200 color layer.
  `PaintRegions` labels every closed area once when a page opens; a fill writes into one area's mask,
  grown 2 px under the ink so no white shows at the edges. Brushes clip to the area the stroke started in.
- Saves live in `Application Support/Games/coloring/` (`gallery.json`, `<id>.png`, `<id>.stickers.json`, `<id>.jpg`).

## Adding pages
Add a function to a `pages_*.py` file and to that file's list, run `python3 tools/make_coloring.py --check`,
look at the preview sheet, then commit the regenerated files. Keep page ids stable: saved pictures refer to them.
