# Gameplay: the Sparkle Path

## Why the old loop felt flat

- **One verb.** Everything was "drag a sticker onto the doll". Wishes, secrets and the House all used the same motion, so after ten minutes nothing felt new.
- **No goal you can see.** Stars filled a 5-star jar and that was it. Nothing said "you are halfway to something".
- **No challenge.** A wish could not go well or badly, so finishing one felt the same every time.
- **Rewards that don't do anything.** Hatched Glimmies sat on a shelf. Nothing unlocked, and the 8 Glimmies ran out after about 40 wishes.
- **No surprises.** The egg was the only reveal, and it was always the same egg.

## The new loop

The home screen is now a **map**: a winding path of 12 stops through a world, ending at a landmark.
Her avatar and her Glimmie buddy stand on the next stop, which glows.

| Stop | What she does | Stars |
|---|---|---|
| 🌟 Star Catch | Slide her Glimmie under falling stars, hearts and candy for 30 s. Rainbows are worth 3; rain clouds just make it wet. | 1 to 3 by catches |
| 👗 Fashion Show | A Glimmie wish in the closet, then she walks the runway while cameras flash and three Glimmie judges hold up hearts. | 3 |
| 🃏 Match Cards | Memory pairs with closet stickers. A quick peek first, then 3, 4 or 6 pairs as she goes. | 1 to 3 by misses |
| 🫧 Bubble Pop | Pop the bubbles of the color the voice asks for; the color changes every 4 pops. Golden bubbles count double. Teaches colors. | 1 to 3 by mistakes |
| 🎵 Glimmie Dance | Four Glimmies each sing a note. Watch the pattern, then copy it; it grows to 4 to 6 notes. | 1 to 3 by mistakes |
| 🎁 Treasure | Every 4th stop. Tap 3 times to open: a new stage backdrop for the closet, or at the end of a world a magic egg. | |

- Games can't be lost: the worst result is one star and "Nice try!".
- Stars go in the jar; a full jar is a magic egg; the new Glimmie becomes her buddy in the games.
- Four worlds (Candy Meadow, Cloud Castle, Mermaid Lagoon, Starry Sky), each with its own colors. Finishing one is a party. After the fourth, the path starts over a bit harder (more cards, faster stars, longer dances).
- Finished stops can be replayed for stars any time. Best scores are kept, and beating one shows a trophy.
- 12 Glimmies to collect (4 new colors) and 8 stage backdrops.
- Free play is still there: the dress button opens the closet with wishes and secret looks, and the closet's picture button switches backdrops.

## Code

- `Adventure.swift`: stops, worlds, backdrops
- `MapView.swift`: the map, chests, world-finished party, egg hatching
- `MiniGames.swift`: Star Catch, Bubble Pop, Match Cards, Glimmie Dance, results screen
- `FashionShow.swift`: the runway
- Save data: `SaveData.adventure` (stop, backdrops, buddy, best scores)

Screenshots for every game: run **Build iPad app** with "Commit simulator screenshots", or launch with
`-demoMap -demoPlay catchStars|dress|memory|bubbles|dance|chest`.
