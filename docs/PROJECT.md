# Glimmie: project notes

Made for an almost-5-year-old who plays on an iPad (sideloaded with Feather).

## Rules for every game
- Everything is free and unlocked. No ads, no purchases, no timers or "come back tomorrow".
- No system text-to-speech. If a game ever needs a voice, ship recorded audio files.
- Big touch targets, pictures instead of words (she can't read yet), a sound on every tap.
- Original art and names. Games can share a genre with a store game, never its characters, art or look.

## Layout
```
App/Sources/Drawer/      the home screen (game drawer), app entry, GameRegistry
App/Sources/Shared/      Theme, DesignCanvas, HomeButton, Sound (effects only), GameStorage
App/Sources/Games/<X>/   one folder per game
App/Resources/Games/<X>/ that game's files (bundled as a folder; load with GameFiles.url)
tools/dressup/           Python that draws the Dress Up art and writes dressup.json
tools/petvet/            Python that draws the Pet Vet art (petvet.json) and makes its sounds
```

Saves: each game writes only to `Application Support/Games/<game id>/`.
Dress Up keeps `current.json` (what she's wearing now) and `gallery.json` (up to 60 saved looks).

## History
Version 1.0.48 and earlier were "Glimmie Closet", a Blender-rendered sticker dress-up game with a map
of mini-games and a text-to-speech voice. Rico retired it in Nov 2026 ("it all sucks"); it lives in git
history before the game-drawer PR.

## Dress Up art decisions
- Flat cute 2D vector chibi (about 2.2 heads tall), color-derived outlines (never black), one shade and
  one highlight per color. Shade math is in `tools/dressup/colors.py` and mirrored in `DressUpArt.swift`.
- Items are colored by role, so every clothing item works in all 24 colors and 7 patterns.
- A dress replaces a top and bottom; picking a top or bottom takes the dress off.

## Pet Vet decisions
- Same flat chibi look as Dress Up: color-derived outlines, one shade and one light per color (math in tools/petvet/base.py).
- All 16 animals share one sitting body plan, so problem spots (named anchors in animals.py and VetAnchors in Swift) land on fur for every animal.
- Each ailment is a short recipe of tool steps (rub, hold or touch). Spots can be treated in any order; unneeded tools still do something fun.
- Needed tools wiggle with a pink ring on the shelf, and a dashed ring shows where to use the lifted tool.
- Saves `clinic.json`: hearts earned per patient, current problems, and bows/bandages she stuck on them.

## Coloring brush decisions
- Every brush copies the physical tool on paper (code and notes in `App/Sources/Games/Coloring/Brushes.swift`).
  A shared paper "tooth" texture (`PaperTooth`) is what crayon, pencil and eraser catch on.
- A stroke is repainted from the paper as it was when the stroke began plus how much of the stroke each pixel got,
  so markers stay even inside one stroke and only darken (and mix colors) where a new stroke crosses.
- Watercolor dries for about a second after each stroke: lighter middle, darker edges, pigment in the grain.
- Glitter (brush and glitter fill) leaves flakes that twinkle live on a layer above the page, and shimmer when the
  iPad tilts. Flakes are saved next to the color layer as `<id>.glitter`; the eraser and any fill over them remove them.
- Apple Pencil pressure and tilt are used (tilted pencil shades wide and soft); a finger draws at a steady medium pressure.
