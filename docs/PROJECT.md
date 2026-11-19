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

## Dress Up pet corner
- The pets share the Pet Vet animals' body plan and drawing code (`tools/petvet/animals.py`, which now keeps each animal's
  torso, limbs and head apart), plus four of their own in `tools/dressup/pets.py` (dragon, red panda, owl, axolotl).
  They are written into `dressup.json` under `pets` and drawn by `PetArt.swift`.
- Outfits are drawn once on the shared body and placed with per-pet anchors (hat on the head top, glasses on the eyes,
  garments scaled to body width). Layer order: back wear, tail/ears, torso, body wear, paws, head, collar, front, face,
  glasses, hat. Outfit colors use the Dress Up color roles, so every piece works in all 24 colors.
- `PetLife.swift` is the living stage (one class, drawn every frame like `DollMotion`): idle breathing, blinking, eyes that
  follow the finger or toy, hops with squash and stretch, and every care tool. Every tool also works with a single tap.
- Each pet has a favorite snack (`PetSave.favorites`); after 3 hearts the shelf marks it with a little heart.
- The thought bubble only ever asks to play; doing what it shows gives extra hearts. Nothing gets hungry or sad.
- Taking a pet along stores a copy of it in the look (`Look.pet`); it sits at her feet and counts in fashion battles.
  Old looks that held p_kitty/p_puppy/p_bunny/p_duck/p_unicorn move that pet to her feet; p_teddy stays a held plush.
- Screenshot hooks: `-petDemo dressed | closet | pets | foam | sleep | feed`, `-demoCompanion`.

## Pet Vet decisions
- Same flat chibi look as Dress Up: color-derived outlines, one shade and one light per color (math in tools/petvet/base.py).
- All 16 animals share one sitting body plan, so problem spots (named anchors in animals.py and VetAnchors in Swift) land on fur for every animal.
- Each ailment is a short recipe of tool steps (rub, hold or touch). Spots can be treated in any order; unneeded tools still do something fun.
- Needed tools wiggle with a pink ring on the shelf, and a dashed ring shows where to use the lifted tool.
- So her finger never hides the work: the tool tip works 80 pt above her finger, the tool turns see-through (and a
  bit smaller) over the patient with a small pink ring at its tip, and a round magnifier near the top shows the spot
  under the tip at 2x on the side away from it. Screenshot hook: `-vetHold <tool>` holds a tool over its spot.
- Saves `clinic.json`: hearts earned per patient, current problems, and bows/bandages she stuck on them.

## Bakery realism
- The mixing bowl is a small simulation (`MixBowl.swift`): ingredients pour as particles or liquid streams and land as
  blobs on the batter surface; the spoon drags, stretches and splits blobs so colors marble, and each blob blends toward
  the flavor color as it's worked. Mixing is done at 96% blended (or after a safety amount of stirring).
- Pouring into the pan is press-and-hold (`BakeStep.swift`, `PourFlow`): 2.4 s of pouring fills it; a quick tap still pours 0.8 s.
- Cake frosting keeps its spatula strokes in `Treat.swoosh` (flat x, y pairs, optional so older saves load), and
  TreatPainter draws the ridges on every cake afterwards. Cupcake rings are piped with an angular sweep (`Piping`).
- Ingredients go in by hand (`HandsOn.swift`, `HandsOnBowl`): drag flour, sugar or milk over the bowl and it tips and
  pours while held (shaking the flour pours faster, like sifting); a ring around the plate fills and a tick appears when
  there's enough. Eggs can't pass through the rim: pushing one down onto the rim knocks it (first knock cracks it, second
  breaks it open), or let it go on the rim and tap it. Butter drops in when let go over the bowl. A tap on a plate shows
  a ghost gliding to the bowl. Everything feeds `BowlSim` the same blobs and pool growth a scripted pour does.
- Screenshot hooks: `-bakeryDemo pour | crack | stir | pourpan | bake | spread | pipe | sauce` freeze a step mid-action.

## Bakery orders
- Each customer orders one exact treat (`BakeryOrder`): kind, flavor, frosting color (cone for ice cream) and one topping.
  The wish bubble shows that treat, with its four parts under it; the kitchen pins the same card (`OrderCard`) top left.
- A part gets a green tick once the treat matches it; the matching choice in each picker wears a heart badge
  (`.wanted`, fed through the `bakeryOrder` environment value). Ice cream's flavor matches if any scoop has it.
- Serving gives gentle stars: 3 for all four parts, 2 for two or three, 1 otherwise. Every treat is still eaten happily.
  The stars go into the heart jar. `-bakeryRated` serves the exact order for a screenshot.

## Coloring brush decisions
- Every brush copies the physical tool on paper (code and notes in `App/Sources/Games/Coloring/Brushes.swift`).
  A shared paper "tooth" texture (`PaperTooth`) is what crayon, pencil and eraser catch on.
- A stroke is repainted from the paper as it was when the stroke began plus how much of the stroke each pixel got,
  so markers stay even inside one stroke and only darken (and mix colors) where a new stroke crosses.
- Watercolor dries for about a second after each stroke: lighter middle, darker edges, pigment in the grain.
- Glitter (brush and glitter fill) leaves flakes that twinkle live on a layer above the page, and shimmer when the
  iPad tilts. Flakes are saved next to the color layer as `<id>.glitter`; the eraser and any fill over them remove them.
- Apple Pencil pressure and tilt are used (tilted pencil shades wide and soft); a finger draws at a steady medium pressure.
- Two fingers pinch to zoom (up to 4x) and drag the zoomed page (`Zoom.swift`, touch handling in `ColoringCanvasView`).
  A stroke the first finger started less than half a second earlier is taken back when the second finger lands, and the
  fill tool fills when the finger lifts, so a pinch never leaves a mark. A quick two-finger tap, or the pink button that
  appears in the top bar while zoomed, shows the whole page again. Brush sizes stay in paper pixels, so zooming in makes
  the brush finer on the page. Apple Pencil strokes ignore extra fingers (resting hand).
