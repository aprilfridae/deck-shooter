# Split Deck: project handoff

Read this first, then continue from "Where we are now". Last updated 2026-11-05.

## The project

Split Deck is a Roblox PvP shooter: fast Black Ops style movement, 2 guns plus a 3-card ability deck, and a social hub for rolling card packs. It was called Deck-Shooter in older docs. The Roblox place and the repo (`aprilfridae/deck-shooter`, default branch `main`) still use the old name.

- **Parent design spec:** the doc "Deck-Shooter Design Spec" at https://claude.ai/artifact/P6cgJtFzpNRJJcx53PMoMH. It covers the whole game, palette, economy and roadmap.
- **Specs and plans:** `docs/superpowers/specs/` and `docs/superpowers/plans/`. `2026-11-03-movement-combat-design.md` overrides the parent spec for combat.

## Working with River

- River is not a coder. The assistant writes all code. Use they/them. Casual tone; River sometimes says "Goat".
- River is token-conscious. Keep replies short and specific.
- **River does all Play testing.** Never start Play through tools. Give a short list of what to check. Reading the Studio console or instances is fine, and is only possible while River is in Play.
- **Commit, push or merge only when River asks.**
- Never edit scripts through Studio MCP. Rojo syncs from this repo.
- Say what's unverified. River catches wrong assumptions fast, so find the real cause before claiming a fix.
- All guns are hip fire only, except the Longscope, which can scope. The base and firing gun pose always points straight.
- Don't remove or change animations when asked to change only a sound, and don't change timing when asked to change position.

## Tools and setup

- **Tests:** `export PATH="$HOME/.rokit/bin:$PATH"; lune run tests/run.luau` (345 passing). New specs must be listed in `tests/run.luau`.
- **Rojo:** `rojo serve`, port 34872. If Studio reopens, River reconnects the plugin. A running server misses new `default.project.json` mappings, so put new modules in folders already mapped, such as `src/shared/Guns/` and `src/client/`.
- **Sounds:** live in `assets/sounds/` and load as `rbxasset://sounds/deckshooter/`. They are not uploaded to Roblox yet. Run `sh tools/install-sounds.sh` after adding one, and after any Studio update, because updates wipe them. Studio caches sounds, so give a changed sound a new filename (for example `-v2`). Strip extra WAV chunks when importing; they caused a click once. `GunSounds.luau` lists them all.
- **River's sound folders:** `E:\sound effects for game\`, with GUN RELOAD, MOVEMENT SOUNDS, MENU MUSIC and MENU SOUNDS.
- **Font sheets:** Roblox can't import fonts, so `python tools/export_font_atlas.py <font folder>` makes image sheets in `assets/hud/` and writes `GlyphData.luau`. Changed sheets are uploaded to Roblox and their ids go in `src/shared/Guns/Hud/FontImages.luau`. Upload by serving `assets/hud` on a local `http.server` and using the Studio `upload_image` tool. Trial and free font zips are in River's Downloads: `KH-Interference-TRIAL.zip` and `PPFraktion-Free_for_personal_use_v1.1.zip`.
- **Arm animation:** `tools/export_arm_clips.py` runs in background Blender (`H:/blener/blender.exe`) on `H:/player models/M57 Arms Posed.blend` and `H:/player models/Energy Pistol Arms Posed.blend`, and overwrites `src/shared/Guns/ArmClips/<Gun>.luau`. Run it through the wrapper: `blender.exe -b <file> --python tools/arm_bg.py -- "M57"` or `"Energy Pistol"`. After every pistol export, run `python tools/resample_clip.py src/shared/Guns/ArmClips/EnergyPistol.luau <clip> 24 24.9 7 14` for `reload`, `reload2` and `reload3`. The M57 fps is 24.37, set in the export script.
- River's open Blender may hold unsaved work in `Marathon guns V3.blend`. Never touch it.
- Node isn't installed, so the brainstorming browser companion doesn't work. Mockups go in `.superpowers/` as plain HTML.

## What's built

- Movement: sprint, slide, chain jumps, parry, climb. `src/shared/Movement/`, `src/client/Movement.client.luau`.
- Guns, with first-person arms, reloads and sounds. Each of the M57 and pistol has 3 reload takes that differ only in position.
- Abilities and the card core: cards, fusion, Deck Power Rating, income, saves through ProfileStore.
- HUD in River's fonts, using image text (`TypeLabel`).
- The doc's palette across the game: `src/shared/Guns/Palette.luau`.
- Sounds: guns, hits, kills, low health, footsteps, jumps, menu music, selection. Roblox's default running sound is muted on every character.
- Title screen: `src/client/TitleScreen.client.luau`, with `MenuState.luau` and `MusicBars.luau` in `src/shared/Guns/`.

## Title screen details

- Stacked SPLIT DECK (Bone, Signal Acid) on navy, with a diagonal cut to Signal Acid. The cut slides and tilts gently with the cursor (`CUT_DRIFT`, `CUT_TILT`).
- PLAY works. LOADOUT and SETTINGS are dimmed with SOON. PLAY's hover turns acid with `>`.
- `MenuState` blocks all `Input` reads and the HUD until PLAY. WASD is blocked by disabling the default controls. It shows once per join.
- Visualizer at the bottom right: 36 by 15 segmented bars, with the barcode above them. It uses `PlaybackLoudness`, which is one number, so the bars are a pattern, not real frequencies.
- Music (`menu-music-v2.mp3`) loops. After PLAY it keeps playing at volume .224 with lows at -12 dB and mids at -1 dB. The selection sound plays on the PLAY click.

## Where we are now

All the work above is merged to `main`. Nothing is half built.

**Unconfirmed, ask River about these:**
- A copy of the menu showed in the top left at launch. The cause was never found. The screen now clears everything before each redraw, which was a guess. If it's still there, have River stay on the title screen in Play, then read `PlayerGui` through the Studio client.
- None of the title screen's later additions have a confirmed check in Play: visualizer position, parallax, in-game music levels, selection sound and the PLAY `>`.
- The selection sound plays on click. River might have meant hover.
- Roblox's default jump and landing sounds are still on and may overlap the new jump sound.

**Known gaps:**
- Other players' footsteps can't be heard, because the default is muted and ours are local only.
- No landing, climb or parry sounds. The M57 hit isn't aligned to the new assault reload sound.
- Full fonts: River will download them, then re-export, upload and update `FontImages.luau`.
- Sounds must be uploaded to Roblox before launch, then swapped to `rbxassetid://`.
- The parent doc still says Deck-Shooter, Michroma and Roboto Mono. The design doc's Pistol reload is out of date (actual: Pistol .964s, M4 and AK47 .985s).
- A lag issue was noticed earlier and never diagnosed. The console also shows `CardCoreRemotes.Snapshot` events with no listener.

**Next up:** Phase 4 Matches is parked until gameplay looks, sounds and feels good. River decides what's next.
