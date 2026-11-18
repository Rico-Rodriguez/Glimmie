# Glimmie Closet — project notes

A dress-up sticker game for an almost-5-year-old, played on an iPad (sideloaded).
Inspired by the reusable dress-up sticker books she loves and by the *style* of
Teenieping (big glossy eyes, sculpted candy-colored hair, soft vinyl-toy look).
All characters and art here are original; no Teenieping characters are copied.

## What was decided

| Topic | Decision |
|---|---|
| Scope | Master **one** game mode first: the Boutique (dress-up). Town map, studio, runway, arcade, etc. are later. |
| Player character | She designs **her own avatar** (skin, hair style, hair color, eye color). Other "friend" girls are a later idea. |
| Interaction | **Drag** stickers onto the doll (not tap). Tap gives a gentle "drag it!" hint. |
| Art | Rendered in **Blender** (headless `bpy`, Cycles), not hand-drawn SVG. Soft vinyl-toy look, sculpted (voxel-fused) hair, eyes as shrink-wrapped decals. |
| Art pipeline | Every piece is rendered from **one fixed camera** on a transparent background, so layers stack with zero alignment work. Tintable pieces are rendered near-white and colored in-app by multiply. |
| Platform | Native **SwiftUI** iPad app (landscape), built by a **GitHub Action** into an unsigned `.ipa` for sideloading (AltStore / Sideloadly). |
| Reading | Assume a pre-reader: voice prompts (AVSpeechSynthesizer), icons not words. |

### Things that did not work (so we don't repeat them)
- Hand-coded SVG characters and web mockups: looked homemade ("9th grader").
- Primitives (spheres/cones) for hair: read as floating blobs → fixed by fusing
  shapes with a voxel remesh + smoothing so hair is one sculpted mass.
- Eyes as 3D shapes pressed into the head: sank into the face (teardrop /
  half-circle shapes) → fixed with flat decals projected onto the head.
- Heavy lash arches + big black pupils: read creepy → thin lid line, mostly-iris
  eyes with dark-top → light-bottom gradient, big highlights, eyes set low.

## What's done

### Art (`art/`)
- `art/blender/avatar_layers.py` — builds the avatar and every wearable, renders
  each layer: `python avatar_layers.py -- <outdir> ALL` (or a list of layer names).
- `art/blender/glimmie_layers.py` — Glimmie pet as a tintable body + untinted face.
- `art/renders/` — raw 800×1000 RGBA renders (avatar) and 600×600 (Glimmie).

Layers (draw order, back → front):

| Layer | Tint | Notes |
|---|---|---|
| `wings_fairy` | yes | drawn first so the body hides it |
| `skin` | yes (skin tone) | body + head |
| `under` | no | white tank + bloomers |
| `eyes` / `eyeshine` | eyes: yes (eye color) / shine: no | `happy` (^ ^) replaces both for blinks & cheers |
| `face` | no | blush + open smile |
| `shoes_mary`, `shoes_boots` | yes | |
| `dress_aline`, `dress_tutu`, `dress_gown`, `dress_puff` | yes | |
| `hair_curls`, `hair_long`, `hair_buns` | yes (hair color) | include bangs |
| `hat_crown`, `hat_flowers`, `hat_star` | no | gold / multicolor |
| `hat_bow`, `hat_ears` | yes | |
| `hold_wand`, `hold_bouquet` | no | |
| `hold_balloon`, `hold_purse` | yes | |
| `glim_body` / `glim_face` | body: yes / face: no | 8 Glimmies = 8 tints |

- `tools/process_art.py` — copies layers into the app (`L_*.png`) and makes a
  cropped sticker icon (`I_*.png`) + white die-cut border (`B_*.png`) per item.

### App (`App/`) — see `App/README` section in the main README once added.

## What's next
1. **App v1 (Boutique)**: avatar maker on first launch; Boutique with sticker
   drawer (tabs + color dots), drag-to-wear with peel/wobble/snap, Glimmie
   friends asking for outfits (voice), stars → egg → hatch new Glimmie,
   secret combo looks, sounds, saved progress.
2. **GitHub Action** builds the unsigned `.ipa` on every push (artifact).
3. Play-test with her → tune what she loves / where she gets bored.
4. Art polish backlog:
   - tutu reads a bit like a flat disc; give it ruffles
   - balloon partly hidden by long hair; move it out
   - hair "shine band" highlight; more hairstyles; more outfits (tops/skirts, PJs, swimsuit)
   - blink/cheer animations are layer swaps today; could add arm-wave layer
   - egg is drawn in-app for now (Blender egg looked dull)
5. Later modes (mocked up earlier, not built): town map, Glimmie House care,
   Design Studio (paint your own dress), capsule machine, runway, decorate room,
   mini-games, daily mailbox, story chapters.
