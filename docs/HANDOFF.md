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
- **Every coding session ends pushed to GitHub (River's rule).** When the work is finished and the tests pass, merge it into `main` and push before the session ends. `.kiro/steering/push-every-session.md` has the steps. The repo is code only: never commit `assets/`, place files or API keys.
- Never edit scripts through Studio MCP. Rojo syncs from this repo.
- Say what's unverified. River catches wrong assumptions fast, so find the real cause before claiming a fix.
- All guns are hip fire only, except the Longscope, which can scope. The base and firing gun pose always points straight.
- Don't remove or change animations when asked to change only a sound, and don't change timing when asked to change position.

## Tools and setup

- **Tests:** `export PATH="$HOME/.rokit/bin:$PATH"; lune run tests/run.luau` (351 passing). New specs must be listed in `tests/run.luau`.
- **Rojo:** `rojo serve`, port 34872. If Studio reopens, River reconnects the plugin, in edit mode (connecting during Play fails with "Http requests can only be executed by game server"). A running server misses new `default.project.json` mappings, so put new modules in folders already mapped, such as `src/shared/Guns/` and `src/client/`. The server doesn't survive a restart of the computer; check it's listening on 34872 when River says changes aren't showing up.
- **Collaborators and the group:** the game now lives in the Fridae Studios group (group 237720778, owner River), experience "SplitDeck" (universe 10774901448, root place 70756985983915, private). The repo is code only; README.md has the setup. The group's place holds `ReplicatedStorage.GunModels` (guns, `Arms`, `Card`), Lighting with its `ColorGrading` and `Bloom`, and the place settings; Rojo leaves those alone. Sounds, Outpost textures and font sheets are group assets (ids in `SoundIds.luau`, `OutpostAssets.luau`, `Hud/FontImages.luau`, uploaded 2026-11-05). Uploaded audio only plays in group-owned experiences. `tools/upload-group-assets.py` uploads new files with a group API key from `ROBLOX_API_KEY`. Local working copies stay in `assets/`, which git ignores. The older user-owned assets and experience (universe 10774583287) still exist on River's account but aren't used.
- **Studio MCP without Kiro's config:** Kiro can talk to Studio through `%LOCALAPPDATA%\Roblox\Versions\<version>\StudioMCP.exe` over stdio, using a small Python MCP client. `execute_luau` replies are cut off at about 100k characters, so large exports are kept in `_G` and read back in chunks. `SerializationService:SerializeInstancesAsync` makes `.rbxm` bytes. Studio blocks reading `Lighting.Technology` from there.
- **Sounds:** River's source takes are prepared with `tools/pad-sounds.py` into `assets/sounds/` (local only), then uploaded to the group; `GunSounds.luau` lists them and errors at load if one has no id in `SoundIds.luau`. Roblox caches sounds by id, so a changed sound gets a new upload and id. Strip extra WAV chunks before uploading; they caused a click once.
- **River's sound folders:** `E:\sound effects for game\`, with GUN RELOAD, MOVEMENT SOUNDS, MENU MUSIC and MENU SOUNDS.
- **Font sheets:** Roblox can't import fonts, so `python tools/export_font_atlas.py <font folder>` makes image sheets in `assets/hud/` (local only) and writes `GlyphData.luau`. Upload changed sheets to the group with `tools/upload-group-assets.py` and put their ids in `src/shared/Guns/Hud/FontImages.luau`. Trial and free font zips are in River's Downloads: `KH-Interference-TRIAL.zip` and `PPFraktion-Free_for_personal_use_v1.1.zip`.
- **Arm animation:** `tools/export_arm_clips.py` runs in background Blender (`H:/blener/blender.exe`) on `H:/player models/M57 Arms Posed.blend` and `H:/player models/Energy Pistol Arms Posed.blend`, and overwrites `src/shared/Guns/ArmClips/<Gun>.luau`. Run it through the wrapper: `blender.exe -b <file> --python tools/arm_bg.py -- "M57"` or `"Energy Pistol"`. After every pistol export, run `python tools/resample_clip.py src/shared/Guns/ArmClips/EnergyPistol.luau <clip> 24 24.9 7 14` for `reload`, `reload2` and `reload3`. The M57 fps is 24.37, set in the export script.
- River's open Blender may hold unsaved work in `Marathon guns V3.blend`. Never touch it.
- Node isn't installed, so the brainstorming browser companion doesn't work. Mockups go in `.superpowers/` as plain HTML.
- **Kiro MCP:** Kiro can't write its own settings. The Blender and Roblox Studio MCP config is staged in `.superpowers/kiro-mcp.json`; River copies it to `~/.kiro/settings/mcp.json` and restarts Kiro. uv and the MCP for Blender addon are installed. Blender MCP drives whichever Blender window is open, so save `Marathon guns V3.blend` and open a blank file first.

## What's built

- Movement: sprint, slide, chain jumps, parry, climb. `src/shared/Movement/`, `src/client/Movement.client.luau`.
- Guns, with first-person arms, reloads and sounds. Each of the M57 and pistol has 3 reload takes that differ only in position.
- Abilities and the card core: cards, fusion, Deck Power Rating, income, saves through ProfileStore.
- HUD in River's fonts, using image text (`TypeLabel`).
- The doc's palette across the game: `src/shared/Guns/Palette.luau`.
- Sounds: guns, hits, kills, low health, footsteps, jumps, menu music, selection. Roblox's default running sound is muted on every character.
- Title screen: `src/client/TitleScreen.client.luau`, with `MenuState.luau` and `MusicBars.luau` in `src/shared/Guns/`.
- The Outpost hub, step 1: the place itself. Spec: `docs/superpowers/specs/2026-11-05-outpost-design.md`. Built at server start by `src/server/Outpost/` (`Kit.luau` helpers, `Map.luau` layout, `Outpost.server.luau` zones and travel). `src/client/Outpost.client.luau` applies its fog and lighting and draws sign and screen text. PLAY lands on its dock. Lift doors in its east corridor go to the test room, and a terminal by the test room spawn comes back. `Zones.luau` makes the Outpost a safe zone: no guns, cards or combat HUD.

## Title screen details

- Stacked SPLIT DECK (Bone, Signal Acid) on navy, with a diagonal cut to Signal Acid. The cut slides and tilts gently with the cursor (`CUT_DRIFT`, `CUT_TILT`).
- PLAY works. LOADOUT and SETTINGS are dimmed with SOON. PLAY's hover turns acid with `>`.
- `MenuState` blocks all `Input` reads and the HUD until PLAY. WASD is blocked by disabling the default controls. It shows once per join.
- Visualizer at the bottom right: 36 by 15 segmented bars, with the barcode above them. It uses `PlaybackLoudness`, which is one number, so the bars are a pattern, not real frequencies.
- Music (`menu-music-v2.mp3`) loops. After PLAY it keeps playing at volume .224 with lows at -12 dB and mids at -1 dB. The selection sound plays on the PLAY click.

## Where we are now

All the work above is merged to `main`. Nothing is half built.

**Outpost decisions from River:** amber is for world lights only; signs and screens use the palette. The only booth is the Market kiosk. Loadout and Credits will be HUD or GUI features, not places. Outdoor rain around the camera was removed because it looked wrong.

**Unconfirmed, ask River about these:**
- Outpost floor z-fighting: the island rock was lowered to sea level and filled voxel by voxel. Not yet checked in Play.
- Outpost grime, streak and puddle textures, and whether the lamp shadows work (they need Future lighting).
- A copy of the menu showed in the top left at launch. The cause was never found. The screen now clears everything before each redraw, which was a guess. If it's still there, have River stay on the title screen in Play, then read `PlayerGui` through the Studio client.
- None of the title screen's later additions have a confirmed check in Play: visualizer position, parallax, in-game music levels, selection sound and the PLAY `>`.
- The selection sound plays on click. River might have meant hover.
- Roblox's default jump and landing sounds are still on and may overlap the new jump sound.

**Known gaps:**
- Other players' footsteps can't be heard, because the default is muted and ours are local only.
- No landing, climb or parry sounds. The M57 hit isn't aligned to the new assault reload sound.
- Full fonts: River will download them, then re-export, upload and update `FontImages.luau`.
- River couldn't open the group experience in Studio: "We could not open the place [70756985983915]. Failed to fetch place info." The place and experience are fine (checked through Open Cloud: version 2 published and approved). It's a known 2026 Studio bug; Roblox staff suggest logging out of Studio, ending it in Task Manager and logging back in. River's group role is listed as "Member" (rank 1) and the group has no Owner role, which is worth checking in the group's settings if the fix doesn't work.
- The parent doc still says Deck-Shooter, Michroma and Roboto Mono. The design doc's Pistol reload is out of date (actual: Pistol .964s, M4 and AK47 .985s).
- A lag issue was noticed earlier and never diagnosed. The console also shows `CardCoreRemotes.Snapshot` events with no listener.

**Next up:** the 1v1 map, then the Outpost's Market (needs pack rolling), the Loadout button and the Credits HUD. Outpost ambient sounds wait on River's rain, sea and hum loops. Phase 4 Matches is parked until gameplay looks, sounds and feels good. River decides what's next.
