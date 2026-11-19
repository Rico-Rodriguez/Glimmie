# Coloring (game in the drawer)

An original coloring book for a pre-reader. No ads, no purchases, nothing locked, no voice.

## What she can do
- **Book:** 279 pages in 15 categories (pets, animals, farm, birds, ocean, bugs, garden, food, magic,
  holidays, home and toys, things that go, sky and space, people, ABC) plus a blank sheet.
  Category tabs are icons, not words.
- **Tap to fill** any area, in 8 styles: solid, glitter, stripes, dots, hearts, stars, rainbow, ombre.
- **Brushes:** marker, crayon (paper grain), glitter pen, rainbow pen, heart/star stamps, eraser,
  in 3 sizes. "Stay inside the lines" is on by default (the button next to the sizes turns it off).
- **24 colors**, **72 stickers** (drag, pinch, twist, or the bigger/smaller/turn/trash buttons).
- **Undo** (12 steps) and **clear** (asks first, with big ✓/✗ icons).
- **Gallery:** every page she works on is saved automatically. ✓ in the studio saves with confetti and
  opens the gallery. From the gallery she can keep coloring a picture; a grown-up can save it to
  Photos or delete it (asks first).
- **Grown-up pages:** hold the gear in the book's header for 1.5 s. A grown-up can make their own tabs
  (shown first in the rail, with the tab's first page as its icon), rename, reorder and delete them, and fill
  them from Photos, Files (images or PDFs, up to 40 pages each) or a built-in browser: search, tap
  "Tap a picture", then tap any coloring page to add it. Any printable page works: it's cropped, fit to 4:3,
  cleaned to black lines (grey shading and paper texture dropped) and thickened so fills don't leak.

## How it works
- Pages are public-domain line art from [Openclipart](https://openclipart.org) (everything there is CC0),
  hand-picked for big, simple, cute shapes. `art/coloring/imported.json` lists every page: its id, category,
  and source (`openclipart:<number>` = `https://openclipart.org/detail/<number>`).
  `python3 tools/import_coloring.py` downloads the SVGs (cached in `art/coloring/svg-cache/`, not committed),
  crops each drawing, letterboxes it to 4:3, drops light grey shading, thickens thin lines and closes small
  gaps in outlines, then writes `App/Resources/Games/Coloring/` (`<id>.png` line art in the alpha channel at
  2048x1536, `<id>_t.png` thumbnails, `pages.json`). `--check` writes region previews to
  `art/coloring/preview/` (each closed area in a random color) and flags pages whose background leaks inside.
- In the app (`App/Sources/Games/Coloring/`) the line art is drawn over a 1600x1200 color layer.
  `PaintRegions` labels every closed area once when a page opens; a fill writes into one area's mask,
  grown 2 px under the ink so no white shows at the edges. Brushes clip to the area the stroke started in.
- Grown-up pages are made on the iPad (`CustomPages.swift`: `ColoringConvert` turns a picture into line art
  with an adaptive threshold, `ColoringCustom` stores them) and live in
  `Application Support/Games/coloring/custom/` (`tabs.json`, `custom-<id>.png`, `custom-<id>_t.png`).
  They are never in the repo or the build. Deleting a page whose picture is in the gallery leaves that
  picture's colors on a blank sheet.
- Saves live in `Application Support/Games/coloring/` (`gallery.json`, `<id>.png`, `<id>.stickers.json`, `<id>.jpg`).

## Adding pages
Find a CC0 drawing on Openclipart, add `{"id", "src": "openclipart:<number>", "title"}` to a category in
`art/coloring/imported.json`, run `python3 tools/import_coloring.py --check <id>`, look at its preview
(a page flagged `LEAK?` has an open outline: the fill would spill into the background), then run the tool
without arguments and commit the regenerated files. Keep page ids stable: saved pictures refer to them.
Only use public-domain sources (the repo is public): Openclipart, FreeSVG, PublicDomainVectors.

## Credits
Every coloring page comes from Openclipart and is dedicated to the public domain (CC0 1.0) by its artist.
Thank you to the Openclipart artists who shared them. The source of each page is in `art/coloring/imported.json`.
