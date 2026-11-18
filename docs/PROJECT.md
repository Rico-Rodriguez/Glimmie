# Glimmie Closet — project notes

A dress-up sticker game for an almost-5-year-old, played on an iPad (sideloaded).
Inspired by the reusable dress-up sticker books she loves and by the *style* of
Teenieping (big glossy eyes, sculpted candy-colored hair, soft vinyl-toy look).
All characters and art are original; no Teenieping characters are copied.

---

## 1. Current state (as of this commit)

| Area | Status |
|---|---|
| Art direction | **Locked for now** ("we can rock with this"). Soft vinyl-toy 3D look, rendered in Blender. |
| Art pipeline | **Done.** Scripts render every layer from one fixed camera. |
| Avatar + item renders | **Done.** 25 avatar layers + Glimmie body/face in `art/renders/`. |
| App-ready assets | **Done.** `App/Resources/Art/`: full layers (`L_*`), sticker icons (`I_*`), white die-cut borders (`B_*`). |
| iPad app (Swift) | **v1 built.** Avatar maker + Boutique with drag-to-wear, color dots, wishes, star jar, egg hatching, Glimmie shelf, secret looks, sounds and voice. |
| GitHub Action (.ipa build) | **Done.** `.github/workflows/build-ipa.yml` builds an unsigned `Glimmie.ipa` plus simulator screenshots. |
| Play-testing | Not started. |

### What's in the repo
```
art/blender/avatar_layers.py   builds avatar + all wearables, renders any/all layers
art/blender/glimmie_layers.py  Glimmie pet: tintable body + untinted face
art/renders/                   raw renders (800x1000 avatar, 600x600 Glimmie), RGBA
art/blender/experiments/       prototypes of art changes (model_v2_proto.py: docs/MODEL_UPGRADE.md)
tools/process_art.py           renders -> App/Resources/Art (layers, icons, borders)
tools/compose_layers.py        before/after sheet: shipped layers next to new renders, drawn as the app draws them
tools/make_ramps.py            shadow, base and light tones for every palette color (for ramp tinting)
App/Resources/Art/             app-ready PNGs (~7 MB)
docs/PROJECT.md                this file
docs/MODEL_UPGRADE.md          the exact plan for better models
```

### Layers (draw order, back → front)

All avatar layers are 800×1000 and share one camera, so they stack with no
offsets. "Tint" layers are rendered near-white and colored in the app by
multiplying with the chosen color.

| Layer | Tint | Notes |
|---|---|---|
| `wings_fairy` | yes | drawn first so the body hides it |
| `skin` | yes (skin tone) | body + head, neutral pose, slight head tilt |
| `under` | no | white tank + bloomers (always on) |
| `eyes` | yes (eye color) | greyscale iris gradient, lid line, tiny lashes |
| `eyeshine` | no | white highlights; hidden when `happy` is shown |
| `happy` | no | closed ^ ^ eyes, used for blinks and cheering |
| `face` | no | blush + small open smile |
| `shoes_mary`, `shoes_boots` | yes | |
| `dress_aline`, `dress_tutu`, `dress_gown`, `dress_puff` | yes | |
| `hair_curls`, `hair_long`, `hair_buns` | yes (hair color) | each includes its bangs |
| `hat_crown`, `hat_flowers`, `hat_star` | no | gold / multicolor |
| `hat_bow`, `hat_ears` | yes | |
| `hold_wand`, `hold_bouquet` | no | |
| `hold_balloon`, `hold_purse` | yes | |
| `glim_body` / `glim_face` | body yes / face no | 8 Glimmies = 8 body tints |

Verified: composites of 4 different avatars (different skin, hair style/color,
eyes, outfits) and 4 Glimmie colors all line up and recolor cleanly.

---

## 2. Decisions made (and why)

| Topic | Decision |
|---|---|
| Scope | Master **one** game mode first: the **Boutique** (dress-up). Everything else waits. |
| Player character | She **designs her own avatar** (skin, hairstyle, hair color, eye color). Other "friend girls" are a later idea. |
| Interaction | **Drag** stickers onto the avatar. Tapping only gives a gentle "drag it!" hint. |
| Art | **Blender** (headless `bpy` 5.3, Cycles CPU) instead of hand-drawn SVG/web art. |
| Art method | One fixed camera, transparent renders, layered; tintable pieces rendered white and colored in-app → huge variety from few renders. |
| Platform | Native **SwiftUI** iPad app (landscape), built in the cloud by a **GitHub Action** into an unsigned `.ipa`, then sideloaded (AltStore / Sideloadly sign it with your Apple ID). |
| Reading | Assume a pre-reader: voice prompts (text-to-speech), icons instead of words. |
| Repo | `Rico-Rodriguez/Glimmie` (this repo). |

### Things that did not work (don't repeat them)
- **Hand-coded SVG / web mockups:** looked homemade.
- **Web prototype gameplay:** too shallow ("10% of a game"); a 5-year-old finishes it in minutes.
- **Hair built from separate spheres/cones:** read as floating blobs. Fix: fuse shapes with a voxel remesh + smoothing so hair is one sculpted mass; bangs are their own clumpy fused mass.
- **Eyes as 3D shapes pressed into the head:** parts sank into the face (pinched teardrop tops, half-circles). Fix: flat decals shrink-wrapped onto the head.
- **Heavy lash arches + big black pupils + eyes set high:** read creepy / "serial killer". Fix (from the Teenieping chart): bigger eyes set low under the bangs, mostly glossy iris with dark-top → light-bottom gradient, big white highlights, thin lid line with two tiny lashes, chubbier face, tiny low mouth.
- **Thick outline (Freestyle):** looked cheap; removed.
- **Blender egg:** came out dull with floating spots; plan is to draw the egg in-app.

### Known art issues (polish backlog)
- Still "leans a little creepy" per feedback — eyes/face can be pushed further toward the reference (rounder cheeks, eye spacing, softer lid).
- ~~Tutu reads like a flat disc~~ fixed: three rippled tulle layers.
- Balloon is partly hidden behind long hair.
- No hair shine band; only 3 hairstyles, 4 dresses so far.
- Single neutral pose; waving/arms-up would need extra arm layers.

---

## 3. Future state — the plan

### 3.1 App v1: the Boutique

**First launch → avatar maker**
- Big live preview of her avatar (stacked layers).
- Pick: skin tone (5), hairstyle (3), hair color (8), eye color (5). Icons only, voice reads choices.
- Editable later from a button on the Boutique screen.

**Boutique (the one game mode)**
- Left: her avatar on a softly lit stage (dreamy pink gradient, floating sparkles).
- Right: sticker drawer with 5 tabs (dresses, shoes, hats, held items, wings), a row of color dots, and a "take off" sticker.
- **Drag to wear:** sticker peels up (scale + shadow), wobbles with drag speed, avatar glows when hovered, snaps on with a squish + sparkle burst + pop sound. Missed drops spring back to the drawer.
- Tapping a color dot recolors what she's wearing in that tab instantly.
- Avatar blinks on her own and bounces/cheers.

**Goals so it isn't a 5-minute toy**
- A Glimmie friend floats in with a wish bubble (pictures + voice): "Can you wear a blue dress and a crown?" Difficulty grows: 1 item → 2 → 3, with colors.
- Each wish met → stars fly to a 5-star jar → jar full → a magic egg appears → tap 3× to crack → a new Glimmie hatches (8 to collect, shown on a shelf).
- Secret combo looks unlock a fanfare and fill "?" slots (e.g., crown + gown + wings = Fairy Queen; star clips + wand + wings = Star Fairy; flower crown + bouquet + green dress = Garden Girl; bunny ears + balloon + tutu = Party Bunny).
- Free play always works; wishes are optional fun.

**Feel / polish (where most effort goes)**
- Spring animations everywhere, particle bursts, confetti on success.
- Short synthesized sound effects (pop, ding, sparkle, crack, fanfare).
- Text-to-speech voice for every wish (AVSpeechSynthesizer).
- Progress saved on the device (UserDefaults).

### 3.2 App structure (built)
```
project.yml                       XcodeGen config (iPad only, landscape, iOS 16+)
App/Sources/
  GlimmieApp.swift                entry; shows avatar maker on first launch
  Model.swift                     catalog, palette, outfit, wishes, secrets, game state
  SaveData.swift                  what is saved on the device, and the rules for changing it
  Sound.swift                     sound effects + voice
  DollView.swift                  art loader, layered doll (blinks), Glimmie, die-cut sticker
  AvatarMakerView.swift
  BoutiqueView.swift              stage, drawer, drag-and-drop, wishes, star flight
  RewardsView.swift               star jar, egg -> hatch, Glimmie shelf + secret looks
  Effects.swift                   theme, sparkles, confetti, egg drawing, buttons
App/Resources/Art/                generated PNGs
App/Resources/Sounds/             generated .wav files (tools/make_sounds.py)
App/Resources/Assets.xcassets     app icon (tools/make_icon.py)
Tests/SaveDataTests.swift         old saves load, nothing is lost, bad values are clamped
.github/workflows/build-ipa.yml
```

### 3.3 GitHub Action (planned)
- Runs on every push to `main` (and manually) on a macOS runner.
- `brew install xcodegen` → `xcodegen generate` → `xcodebuild` Release for `iphoneos` with code signing disabled.
- Packages `Payload/Glimmie.app` into `Glimmie.ipa` and uploads it as a build artifact.
- To install: download the artifact → sideload with AltStore or Sideloadly (they sign it with your Apple ID; free accounts need re-signing every 7 days).

### 3.4 After v1
The prioritized plan now lives in [ROADMAP.md](ROADMAP.md). The original list is kept below for reference.

1. Play-test with her; tune whatever she loves or ignores.
2. Art polish backlog (above) and more content: more dresses (tops/skirts, PJs, swimsuit), hairstyles, accessories, Glimmie accessories.
3. Later modes (mocked up earlier, not built): town map hub, Glimmie House (pet care), Design Studio (paint your own dress → becomes a sticker), capsule machine, runway dance show, decorate my room, arcade mini-games (laundry sort, find the Glimmie, sewing, memory, bubbles), daily mailbox gift, Heart Kingdom story chapters.

---

## 4. How to re-render the art
```bash
python3 -m venv .bl && .bl/bin/pip install bpy        # Blender as a Python module
SAMPLES=32 .bl/bin/python art/blender/avatar_layers.py -- art/renders ALL
.bl/bin/python art/blender/glimmie_layers.py -- body
.bl/bin/python art/blender/glimmie_layers.py -- face
python3 tools/process_art.py
```
Rendering all 25 avatar layers takes ~6 minutes on CPU.

---

## 5. Building, installing, testing
- Every push to `main` and every PR runs **Build iPad app** on a macOS runner. Download the `Glimmie-ipa` artifact from the run page, then sideload it with AltStore or Sideloadly.
- The same run tests the save data (`Tests/SaveDataTests.swift`) on an iPad simulator. A new version is published only when those tests pass.
- Before changing anything that is saved, read the rules at the top of `App/Sources/SaveData.swift`.
- The `screenshots` artifact has simulator captures of the avatar maker, Boutique, a wish, and the egg.
- Local build on a Mac: `brew install xcodegen && xcodegen generate && open Glimmie.xcodeproj`.
- Launch arguments for testing: `-resetSave` (fresh start), `-demoBoutique` (skip the avatar maker, sample outfit), `-demoEgg` (egg ready to hatch).
- Grown-ups: on the Glimmie shelf, press and hold the small arrow at the bottom left for 3 seconds to reset all progress.
- Regenerate assets: `python3 tools/make_sounds.py`, `python3 tools/make_icon.py`.
