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

## Tools held by their handle (every hands-on game)
- Shared code: `App/Sources/Shared/FingerLift.swift`. Tune the numbers there, not per game.
- Rico, Nov 2026, round 1: lifting tools 120 pt straight above the finger (and the zoom bubble) felt like aiming with a
  gap ("I always want to peek around my finger"). Round 2: tools worked right at her fingertip, and then her finger
  covered them ("I grab the net and the net is under my finger, I can't see what's going on").
- Now a tool is held like a real one: her finger is on the handle and the working end sits a handle's length ahead
  (`FingerLift.tool`, 96 pt), up and to the left, away from her hand (`leanSide`; to the right near the left edge).
  The tool is drawn turned so its handle runs from the working end back to her finger (`turn`, `handle`). Per tool:
  the aquarium net is held by its pink grip (`AquariumView.netGrip`, 134), the garden shovel by its shaft (110),
  sponges and towels by a corner (`FingerLift.grip`, 64). Everything lifted (dragged things, pourers) leans the same way.
- What a tool does reaches well past her fingertip (`FingerLift.spread`, 1.8x): foam, scrubbing, wiping, combing,
  dye, mask paint, the shovel's scoop, the ladle, the net's hoop, a Pet Vet spot's reach. Games multiply their
  effect radii and emitter spreads by it. Held sponges, towels and the bubble wand are drawn bigger too.
- Containers that pour or rain are held above her finger (`FingerLift.pour`, 110 pt): the watering can, the fish food,
  Ice Cream sprinkles, sauces and cream, the showers (Pet Vet, Spa, Salon, pet corner). What falls out lands between
  the container and her finger, so her hand never covers it.
- Dragged things still float a little above her finger (`FingerLift.item`, 100 pt; `carry(below:)` for tall things),
  near the top edge the lift shrinks and leans toward the middle, and near the bottom it turns sideways (`point`).
  `FingerLift.finger(for:)` is the inverse, for screenshot hooks and tests.
- No zoom bubble and no tip ring any more (both removed). Tools still turn see-through over what they work on.
- Tap to do it by itself (`App/Sources/Shared/ToolTap.swift`): in Pet Vet, Garden, Aquarium and Bubble Spa a tap on a
  tray tool picks it (pink ring); while picked, a tap on the scene makes the tool glide there and do that spot
  (`AutoTool` plays a little rub through the game's own drag code), and a drag anywhere uses it directly. Tap the
  picked tool again to put it down. Hair Salon: with a tool picked, a tap on her hair does that spot. Ice Cream: a tap
  in a tub scoops a ball and puts it on the treat. Bakery: a tap on the cake spreads that spot. Pizza, Ice Cream
  toppings and the pet corner already did a whole job on a tap of the tray tool.
- Not lifted on purpose: coloring brushes, pinch and turn coloring stickers, the pet salon (tap only), cupcake
  piping (press and hold), and her bare hand (petting, weeds).

## Play coins (shared by every game)
- One purse for the whole app: `App/Sources/Shared/Coins.swift`, saved in `Application Support/Games/coins/purse.json`.
- Rico, Nov 2026: shop customers pay her in play coins, and she spends them in a treasure shop on the home screen on
  extras (sparkly decorations and Dress Up pieces). Coins only add extras: every tray, tool and item that was
  free stays free, nothing is locked behind coins, no real money, no timers.
- Paying: `Coins.shared.earn(Coins.reward(stars: s), game: id, from: customerPoint)` (3 to 5 coins: every customer pays,
  a happier one a little more). Bakery pays when the treat is eaten, Ice Cream when the treat is eaten at the window,
  Pizza when the whole pizza is eaten.
- Showing it: `CoinCounter(game: id)` in the top bar and `.coinPurse(game: id)` on the 1024 x 834 view that holds the
  customer and the counter; the coins hop out of the customer, arc up and land in the counter one by one with a chime
  (`coin.wav`, and `till.wav` for the till; `python3 tools/coins/sounds.py`). The count goes up as each coin lands.
- Buying: `Coins.shared.buy("<game>/<item>", price:)` (false if she hasn't enough), `Coins.shared.owns(id)`.
- Treasure shop (`App/Sources/Shared/TreasureShop.swift`, items in `Treasures.swift`): tap the coin purse on the home
  screen. Each extra has its game's tile and a price tag. Garden and Aquarium have three decorations each,
  and Dress Up has a moon headband. Tap one
  she can afford and it's bought (green tick) and appears at the end of that game's decorations tray
  (for example, `DecorKind.available` and `ArtCategory.availableItems`). One she can't afford yet wiggles its tag. The drawings are in
  `TreasureArt`, shared by the shop and the games. To add an extra: an entry in `Treasures.all`, a drawing, and the
  game showing it when `Coins.shared.owns(id)`. `-treasureShop` opens the shop on launch.
- Screenshot hooks set `Coins.shared.demo` so they never save coins; `-coinsDemo <n>` starts with n coins, unsaved.

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
- Tools are held by their handle and reach well past it (see "Tools held by their handle"); a tool turns see-through over
  the patient. The shower rains from above her finger.
  Screenshot hook: `-vetHold <tool>` holds a tool over its spot.
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
- Stickers only have SwiftUI gestures while the sticker tool is on, and `ColoringCanvasView.gestureRecognizerShouldBegin`
  refuses every recognizer above the canvas otherwise. (A sticker's drag/pinch/twist recognizers used to cancel her
  strokes, so nothing colored after placing one.) `testThePageTakesTouchesAgainAfterTheStickerTool` guards it.
- Colors: the palette grid, a rainbow hue slider above it, and a paint palette (`Mixing.swift`): she drops blobs of
  color and swirls them with a finger. The paint is a grid of wet cells holding amount and Kubelka-Munk K/S, smeared
  along the finger and blended with neighbours, so it marbles and then mixes like pigment (blue + yellow = green).
  Lifting the finger picks up the paint under it. The palette keeps its paint while the page is open.

## Tidy Up decisions
- Levels are data (`TidyLevels.swift`): a furniture scene (760 x 500 pt, drawn in `TidyScenes.swift` as a back and a
  front layer) plus slots. One item per slot. `strict` slots only take their color (tinted ghost); slots that share a
  `stack` number open bottom-first, and only the top item of a stack can be lifted out.
- Items are drawn in code (`TidyItems.swift`) with color-derived outlines, like the other games. Physics (`TidyWorld.swift`)
  models each loose item as a chain of circles with impulse contacts and friction at 240 Hz; the held item follows the
  finger with lag, swings, and is magnet-pulled toward a slot it fits within 120 pt; dropping snaps it with a spring.
- Saves `progress.json` (finished level ids, music on/off). Nothing is locked; the next unfinished level glows.
- Screenshot hooks: `-tidyLevel <n>`, `-tidyPrefill <k>` (puts k items away), `-tidyHold` (holds one item by its slot),
  `-tidyDemoDone` (marks the first 9 levels done in the picker).

## Garden decisions
- The soil is a height field of 4 pt columns (`GardenSim.h`) with a wetness per column (`wet`). The shovel carves columns down
  to its blade and carries the soil as a load; a flick throws it as clods that settle back where they land, so soil is never
  made or lost (a unit test checks this). Slopes relax to an angle of repose; wet soil holds steeper walls.
- Water and rain are particles that soak into the column they hit. Wetness spreads, dries in the sun, darkens the soil and
  a soak line behind the glass, and pools into flat puddles above 0.85.
- Plants grow only while their soil is damp (about 26 s from seed to ripe) and drink it. A thirsty plant shows a bobbing drop.
  Every plant and weed is a damped spring pushed by wind, rain, water and her finger.
- Saves `garden.json`. Sounds: `python3 tools/garden/sounds.py`. Screenshot hooks: `-gardenDemo`, `-gardenTool can|shovel|seeds`,
  `-gardenWeather sun|rain|wind|night` (screenshot hooks never save).

## Bubble Spa decisions
- The tub is clear glass seen from the side, so filling, waves, bath-bomb clouds and bubbles all show. Things under the
  water are drawn first and the water is laid over them, so the water tints them (`SpaPaint.swift`).
- Water is a depth (`vol`) plus a 1D wave (`h`, `hv`, 148 columns of 5 pt) stepped at 120 Hz; waves are quicker in deeper
  water, reflect off the ends, and the mean is kept at zero so waves never make or lose water. Toys, bombs, her hands, the
  tap's stream, drops and rising air bubbles all push on it.
- Bubble bath only foams when the water is churned (the stream, swishing, fizzing bombs, sponge), like the real thing.
  Foam is a thickness and tint per column; thick foam slumps, drifts to the plug when draining and slowly fades.
- Toys and bombs float by buoyancy (`density` is the part under water at rest). Bombs sink, then bob up once fizzing
  (about 11 s), spin and scoot, dye the water and foam, and some shed glitter that settles on the bottom.
- She is the Dress Up girl's current look with only face, hair, makeup and earrings (`SpaSim.bathLook`). The face mask is
  a 20 x 16 grid between her face and her eyes/mouth layers; it dries in about 9 s, then cracks. Sponge, shower and towel
  wipe it. Two cucumber slices close her eyes; a tap flips one off into the bath.
- Nothing is saved: every bath starts fresh. Screenshot hooks: `-spaDemo full | bomb | mask | wand | towel`.

## Pizza decisions
- One simulation class (`PizzaSim`) stepped every frame by the view, like Garden. Steps (dough, sauce, cheese, toppings,
  oven, cutter) are a bar at the top; any step can be opened at any time and the arrow bounces when one is done enough.
- Dough: a lumpy ball until 6 presses have kneaded it smooth (each press squashes it with a spring and folds the lumps
  smaller), then a disc whose edge is 96 springy radii. Pushing near the edge stretches it; it keeps 60% of the stretch
  and springs back the rest, neighbours pull together like a skin, and bigger dough stretches less. A fast flick up
  (over 900 pt/s) tosses it; it lands 16 pt bigger and rounder. Her bare hand isn't lifted (like petting in Pet Vet).
- Sauce and cheese are 96 x 96 grids over the pizza. The ladle pours where it's held still and pushes sauce along the way
  it moves (mass is kept; `testSpreadingSauceKeepsItAndCoversThePizza`). Cheese shreds fall with gravity, are drawn once
  into a bitmap when they land (`ShredLayer`) and add to the cheese grid, which flows, bubbles and browns in the oven.
  `PizzaGrids` turns the grids into small bitmaps lit by their slope, so they look raised and glossy.
- The oven is its own scene (the pizza drawn squashed on the floor for perspective) with particle fire, embers and a
  flickering glow. A full bake is 9 s; nothing burns. The arrow's ring shows how baked it is.
- Cuts snap to lines through the middle (up to 8). Tapping a slice lifts it out with cheese strings that snap at random
  stretches, and it flies to the customer. Stars (gentle, 1 to 3) count wanted toppings with at least 2 pieces.
- Tools: the ladle and wheel work `FingerLift.tool` above her finger and turn toward it, the cheese bowl and toppings
  are carried above it. A single tap on any tool does a helpful amount by itself.
- Saves `pizza.json` (hearts and pizzas served). Sounds: `python3 tools/pizza/sounds.py`.
  Screenshot hooks: `-pizzaDemo knead | stretch | toss | sauce | cheese | toppings | bake | baked | slice | serve`.

## Ice Cream & Smoothie Shop decisions
- One simulation class (`IceSim`, split over IceCreamSim/Soft/Blender) stepped every frame, drawn by `ICScene` and
  `ICArt` in two Canvas layers (a backdrop that only changes with the station, and the shop). The customer (the
  Bakery's animals, from bakery.json) stands between them so the window sill hides their legs.
- A treat lives in its own space (`ICBuild`): dx across, h up from the rim, z toward her for the soft-serve rope,
  drawn at the stand point `S`. Its top edge as she sees it (`profile`, 2 pt columns) is what sprinkles, sauce, the
  cherry and whipped cream land on.
- Scooping: the dipper's ball grows with the distance dragged inside a tub (240 pt for a full ball); the path is kept
  as grooves in the tub and the tub level drops. Scoops fall onto the cone or the scoop below (`restHeight`), stay
  within a third of its radius, squash on landing and knock the ones below into a damped wobble. Left out, they
  start to drip after about 9 s (never in screenshots).
- Soft serve: beads 5 pt apart chained from the nozzle, laid on the bead one turn earlier while the stand turns,
  so the rope coils into rings that narrow over 6.4 turns; the stand slides under the nozzle and sinks as the swirl
  grows, stops at the top, and the last bit curls up. The twist stripes and ridges turn with the stand.
- Blender: fruit and ice are circles in jar space with walls, friction and impulse contacts. The motor drives two
  rolling vortices; the blades cut a piece smaller or split it, and what it loses becomes juice (`ICPaint`, weighted
  by each fruit's `strength`). The drink's level stays horizontal when the jar tips (found from the jar's polygon and
  the volume); whatever is above the lowest corner of the rim pours out as a ballistic stream. A jar carried over the
  glass tips by itself and drifts so the stream lands in the glass. A new color makes a new layer in the glass.
- Every topping also works with a single tap on the dock (it goes on for her). Everything held follows `FingerLift`.
- Saves `shop.json` (hearts, treats served). Screenshot hooks: `-iceDemo scoop | soft | blend | pour | sundae | serve`.

## Aquarium decisions
- Fish steer (`AquariumSim.stepFish`): each heads for a goal (a wander point in its favorite depth, the nearest flake,
  a spot by her finger) with limited acceleration, keeps room from the others, and tetras and guppies school (cohesion and
  alignment with their own kind). They swim mostly level, pitch a little when they climb or dive, and turn round through
  a narrow side view (`facing` runs from -1 to 1). Tail beat speed and width follow speed and effort; the body outline
  bends with the beat (`AquaBody`), so bands and stripes bend too. Depth `z` makes nearer fish a bit bigger and on top.
- Tapping the glass startles nearby fish (they dart off for under a second) and then they come back to look at the spot.
  A finger resting on the glass for a moment draws them in. Tapping a fish makes it wiggle; the puffer puffs up.
  Nothing gets hungry or sad: appetite only limits how many flakes one fish eats in a row, so others get some.
- Water physics: the surface is 64 spring nodes (waves spread and fade); bubbles rise at a speed set by their size,
  wobble and pop into a ripple; flakes float a moment, then flutter down; decorations sink by buoyancy and drag
  (`AquaDecorKind.density`) and land in a puff of sand. Plants are damped springs pushed by passing fish and her finger.
- The front glass is a 40 x 24 grid of algae that grows slowly (in patches, more near the bottom, slower at night). The
  sponge rubs it off by how far it moves; the snail grazes toward the dirtiest spots. The algae paths are rebuilt only
  when the glass changes.
- Drawing is two layers like the Garden (30 fps backdrop with light rays and caustics, 60 fps moving layer), with
  bubbles, flakes, splash drops and sand grains each batched into a few paths.
- Saves `aquarium.json` (fish kinds and colors, decorations and where they sit, the algae grid, lamp, pump).
  Sounds: `python3 tools/aquarium/sounds.py`. Screenshot hooks: `-aquaDemo`, `-aquaNight`, `-aquaTool food|sponge|net`,
  `-aquaTray fish|decor` (screenshot hooks never save).

## Bigger scenes (Nov 2026)
- Rico picked "just enlarge current layouts". Garden and Aquarium draw the scene (the world) zoomed past the buttons:
  `GMap.garden(size:)` (up to 1.22x, the bed as wide as the screen allows, the front lawn at the bottom, a little sky
  cropped) and `AMap.tank(size:)` (up to 1.18x, the tank frame just above the dock, the cabinet behind it). The maps keep
  `ui`/`uox`/`uoy` for the buttons, and `fromUI` turns a dock spot into a world point (tool homes, auto-do starts).
  Sim coordinates are unchanged.
- Ice Cream's soft-serve machine is bigger (x 360...736) and has four big press-and-hold flavor buttons on its face
  (`ICGeo.softButtons`, radius 30, touch radius 42) instead of four small levers.

## Sticker book and surprises (Nov 2026)
- Rico picked "discover and collect", as "surprises only, trays stay as is", and then a shared sticker book for the
  whole app. Nothing is locked, added to a tray, or asked of her; things just turn up while she plays.
- `App/Sources/Shared/StickerBook.swift`: one book, saved in its own folder (`Games/stickers/stickers.json`), so no
  game touches another game's saves. A game lists its stickers on its `GameEntry` (`stickers:`) and calls
  `StickerBook.shared.find(game:id:)` when she comes across one (cheap to call again). The first time, the
  sticker pops up with stars and flies into the book button (`StickerToast` over the game's controls,
  `StickerBookButton` next to the home button). The book opens from the home screen (top right) or in the game at
  that game's page; missing stickers are soft grey shapes, a row of stars shows how many she has.
- Garden (`GardenFinds.swift`): about one seed in four (`GardenSim.specialChance`) grows a special plant, stored as
  `variant >= Plant.specialVariant` so old saves still load: pink sunflower, blue tulip, a daisy that glows at night,
  pink lavender, purple carrot, golden tomato, white strawberry, giant pumpkin. They twinkle as they grow and count
  when they bloom or ripen. Seven visitors come when the garden has something for them (bunny: ripe carrots;
  frog: rain or a full birdbath; snail: rain; hedgehog: night or a ripe pumpkin; bluebird: birdhouse or birdbath;
  owl: night, on the fence; hummingbird: lavender or a special flower), stay 10 to 18 s and wander off. Ones she
  hasn't met come three times as often. Tapping one makes it hop, curl up, hide or flutter.
- Aquarium (`AquariumFinds.swift`): about one bag in five (`AquaRare.chance`) is a rare colorway, stored as
  `variant >= AquaRare.variant` (galaxy goldfish, blue clownfish, golden angelfish, pink tetras, mint puffer, opal betta,
  golden guppies, teal seahorse); they twinkle and count once they're in the water. Visitors: a crab on the sand and a
  glowing jellyfish when the lights are off, an octopus beside the castle, ship or rock, a sea turtle that swims
  through when the glass is almost clean, and a school of baby fish just after a feed. Sometimes the chest opens on
  a pearl (more likely until she has found it once).
- Shared helpers: `Twinkles.draw` (the little stars around rare things).


## Potion Lab decisions (Nov 2026)
- Rico picked "both" for finding rare potions: secret combos make them, and a light-bulb card shows a picture recipe
  for one she hasn't found yet. The Magic Shop doesn't brew its own potions; potion making lives here.
- The potion is a 48 x 60 grid of 8 pt cells inside the flask (`PotionSim.fluidStep`): stable-fluids advection, an
  18-step pressure projection, light vorticity confinement, premultiplied pigment (r, g, b, amount) and a density field
  (heavy night sky sinks, moon milk floats). Liquid poured in thins what is there (`dilute`), so the same pigment makes
  a bigger, paler potion. Air cells above the surface copy the top cell's color so a rising surface keeps it.
  `PotionLiquid` turns the pigment into a 48 x 60 picture drawn smooth and clipped under the wavy surface.
- Volume sets the level through the flask's shape (`PGeo.areaBelow`). Waves are a row of springs; the whirlpool dip
  comes from how fast it swirls. Foam per column can bubble over the rim.
- Held bottles tip over the mouth (or the unicorn) and only pour once the level liquid inside reaches the bottle's mouth
  (`PPoly.level` finds the level of the tipped outline); the flow pulses (glug). Jars are turned over and drop pieces
  when shaken. Bottles and jars are held `FingerLift.pour` above her finger. The paddle's blade sits
  `PotionLabView.paddleReach` below her finger: she holds the end of its handle and the shaft goes up through the mouth.
- Empty bottles only go in through the mouth when brought down from above (`constrainDip`), fill with the color at
  their mouth and take their share of what's in the potion; lifted out they cork and fly to the rack (11 kept).
- Rare potions (`PotionSim.rareKind`, most particular first): wild (7 things), rainbow, golden, galaxy, dragon (boiled),
  dream, moonlight (lights off), frost, love, mermaid. The flask flashes and pulls its colors toward the potion's.
  Stickers: the 10 potions plus `rainbowUnicorn` and `floatingUnicorn`.
- The unicorn is the Dress Up pet unicorn (`PetPainter.draw`, which now takes an optional `furShading`).
- Saves `potionlab.json` (rack, the flask's volume and mixed color, what's in it, lamp, heat). Sounds:
  `python3 tools/potion/sounds.py`. Screenshot hooks: `-potionDemo mix | pour | shake | stir | boil | dip | unicorn | rare | night | hint`.
- The screenshot workflow takes an `only` input (a name prefix like `potion`) to take just those screenshots.

## Fairies, Garden, and Aquarium loop overhaul (Nov 2026)
- **Fairies F1 (`FairiesModel.swift`, `FairiesSim.swift`, `FairiesArt.swift`, `FairiesGame.swift`, `Shared/PinnedFairyContract.swift`).** Deleted Sparkle Meadow bush hunting so launching opens directly into the 3-station Heart Jewel Compact (`stage`, `salon`, `teaTable`) with all 12 fairies unlocked. Canonical right half-wing coordinates (`WingPoint`) mirror brush strokes, sticking glitter, and dewdrop stamps across Salon, Compact Stage, and Dress Up's `PinnedFairyCompanionView` via `"glimmie.pinnedFairyLook"` alongside unchanged `"glimmie.pinnedFairy"`. `FairiesSim` drops `ObservableObject`/`@Published` for post-frame `Outbox` flushes and a discrete `FairiesTeaUIState` snapshot (0Hz idle chrome). All 3 TreasureShop IDs and 6 `FairiesFind` raw values stay valid.
- **Garden G1 (`GardenModel.swift`, `GardenFarmstand.swift`, `GardenSim.swift`, `GardenScene.swift`, `GardenGame.swift`).** Replaced infinite `0.65` regrowth with finite `PlotStage` (`empty -> growing -> ripe(yieldLeft >= 1) -> empty`), distinct species `growthDuration`/`yieldCount`/`HarvestMechanic`, manual pollen/bee pollination (no autonomous bee breeding), typed `HarvestItem` preserving `isGiant` end-to-end, and the Critter Farmstand (`bouquet`, `jamJar`, `farmBasket`) consuming real inventory with gentle 1-to-3 star scoring and treehouse progression. Legacy `garden.json` (`basket: [String]` and broken ripe plots) migrates cleanly at decode.
- **Aquarium A1 (`AquariumReefBehavior.swift`, `AquariumSim.swift`, `AquariumFinds.swift`, `AquariumDecor.swift`, `AquariumScene.swift`).** Isolated `Grab.submarine` hull drags (`FingerLift.item`) so open water taps and curiosity holds keep working; added egg- and decor-aware `AquaSandLayout.resolve` with peeking sand clues and clams drawn above decor; replaced passive 0.5s sticker auto-unlock with active tap/net discovery across 17 `AquaFind` stickers (including `starlightAxolotl`, `lavenderSeaBunny`, `pastelNarwhal`); wired Night Mode sleeping (`restUntil` + `.sleepBed` anchors) and living decor anchors (`koiBridge`, `castle`, `ship`, `rock`, `shell`, `anemone`, `coral`); added gift-scooping net taps, species-distinct egg patterns, atomic schooling eviction, and pictorial reef play wishes.
