# Split Deck: project handoff

Read this first, then continue from "Where we are now". Last updated 2026-11-07.

## The project

Split Deck is a Roblox PvP shooter: fast Black Ops style movement, 2 guns plus a 3-card ability deck, and a social hub for rolling card packs. It was called Deck-Shooter in older docs. The repo (`aprilfridae/deck-shooter`, default branch `main`) and the Rojo project (`DeckShooter`) still use the old name.

- **Docs:** `docs/README.md` indexes every design spec in `docs/specs/`, lists where they differ from the parent spec, and says which file holds each number. Read the spec for whatever you're changing, and update it in the same pull request when a behaviour or number it states changes.
- **Parent design spec:** "Deck-Shooter Design Spec" at https://claude.ai/artifact/P6cgJtFzpNRJJcx53PMoMH. It covers the whole game, palette, economy and roadmap, and is out of date in places. The specs in `docs/specs/` win.

## Working with River

- River is not a coder. The assistant writes all code. Use they/them. Casual tone; River sometimes says "Goat".
- River is token-conscious. Keep replies short and specific.
- **River does all Play testing.** Never start Play through tools. Give a short list of what to check. Reading the Studio console or instances is fine, and is only possible while River is in Play.
- **Every coding session ends with a pull request and a place build (River's rule).** Work on a feature branch, merge it into `main` through a GitHub pull request, then publish `build/SplitDeck.rbxl` (from `lune run tools/build-place`) as a GitHub release. `.kiro/steering/push-every-session.md` has the steps. The repo is code only: never commit `assets/`, place files or API keys.
- Never edit scripts through Studio MCP. Rojo syncs from this repo.
- Say what's unverified. River catches wrong assumptions fast, so find the real cause before claiming a fix.
- All guns are hip fire only, except the Longscope, which can scope. The base and firing gun pose always points straight.
- Don't remove or change animations when asked to change only a sound, and don't change timing when asked to change position.

## Tools and setup

- **River's working copy is `H:\SplitDeck` (since 2026-11-05).** Work, run Rojo and pull there. When River asks to pull a new version, run `powershell -ExecutionPolicy Bypass -File tools\pull-latest.ps1` in `H:\SplitDeck`: it pulls `main` and downloads the latest release's `SplitDeck.rbxl` next to it. `H:\rblxgame` is the old folder and isn't used.
- **Tests:** `$env:PATH = "$HOME\.rokit\bin;$env:PATH"; lune run tests/run.luau` in PowerShell (509 passing). New test files (`*_spec.luau`) must be listed in `tests/run.luau`, or the run fails.
- **Rojo:** `rojo serve`, port 34872. If Studio reopens, River reconnects the plugin, in edit mode (connecting during Play fails with "Http requests can only be executed by game server"). A running server misses new `default.project.json` mappings, so put new modules in folders already mapped, such as `src/shared/Guns/` and `src/client/`. The server doesn't survive a restart of the computer; check it's listening on 34872 when River says changes aren't showing up.
- **Collaborators and the group:** the game now lives in the Fridae Studios group (group 237720778, owner River), experience "SplitDeck" (universe 10774901448, root place 70756985983915, private). The repo is code only; README.md has the setup. The group's place holds `ReplicatedStorage.GunModels` (guns, `Arms`, `Card`), `StarterPlayer.StarterCharacter` (the low poly player, made with Studio's auto-rigger from `H:player modelsowpoly.glb`, with its root lowered so it stands 3 studs above the feet like the default rig, and `AutomaticScalingEnabled` off because scaling puts the root back; `Movement.client.luau` takes the camera down 0.5 to match), lighting with its `ColorGrading` and `Bloom`, and the place settings; Rojo leaves those alone. Sounds, Outpost textures and font sheets are group assets (ids in `SoundIds.luau`, `OutpostAssets.luau`, `Hud/FontImages.luau`, uploaded 2026-11-05). Uploaded audio only plays in group-owned experiences. `tools/upload-group-assets.py` uploads new files with the group API key from `ROBLOX_GROUP_API_KEY`. Local working copies stay in `assets/`, which git ignores. The older user-owned assets and experience (universe 10774583287) still exist on River's account but aren't used.
- **GitHub CLI and builds:** `gh` isn't logged in on River's machine, but Git Credential Manager holds River's GitHub token. For a command that needs `gh`, read it with `git credential fill` and pass it as `GH_TOKEN` for that command only; never print or save it. `tools/build-place.luau` builds the code with Rojo and adds the place content. With a saved copy of the group's place as its argument it keeps that place and swaps in the code. Without one it uses `assets/models/` (local exports of `GunModels`, `ColorGrading`, `Bloom`) and the lighting values in the script. Downloading the group's place through Open Cloud (`tools/download-place.py`) needs the Legacy Asset permission, which Roblox refuses on group-owned keys; River's user key works. Roblox serves the place gzipped. After a publish the plain download can keep serving an old copy, as it did on 2026-11-06, so pass the version (`game.PlaceVersion` in Studio) as a second argument and check `StarterPlayer.StarterCharacter` is in the file.
- **Roblox API keys:** both are saved as Windows user environment variables on River's machine, never in the repo. `ROBLOX_API_KEY` is River's user key ("for Claude"), with the Legacy Asset permission, for `tools/download-place.py`. `ROBLOX_GROUP_API_KEY` is the Fridae Studios group key ("Fridae API"), for `tools/upload-group-assets.py`. The group key can't download the place: Roblox answered "Scope not authorized" on 2026-11-05. It can also publish places, delete data stores and ban players, so use it only for uploads unless River says otherwise. A shell started before a key was saved won't see it; read it with `[Environment]::GetEnvironmentVariable('ROBLOX_API_KEY', 'User')`.
- **Local asset copies:** checking out a commit from before 2026-11-05's asset removal, then back, deletes the local `assets/` copies. `git restore --source=e63ef3f --worktree -- assets` brings them back without staging them.
- **Studio MCP without Kiro's config:** Kiro can talk to Studio through `%LOCALAPPDATA%\Roblox\Versions\<version>\StudioMCP.exe` over stdio, using a small Python MCP client. `execute_luau` replies are cut off at about 100k characters, so large exports are kept in `_G` and read back in chunks. `SerializationService:SerializeInstancesAsync` makes `.rbxm` bytes. Studio blocks reading `Lighting.Technology` from there.
- **Sounds:** River's source takes are prepared with `tools/pad-sounds.py` into `assets/sounds/` (local only), then uploaded to the group; `GunSounds.luau` lists them and errors at load if one has no id in `SoundIds.luau`. Roblox caches sounds by id, so a changed sound gets a new upload and id. Strip extra WAV chunks before uploading; they caused a click once.
- **River's sound folders:** `E:\sound effects for game\`, with GUN RELOAD, MOVEMENT SOUNDS, MENU MUSIC and MENU SOUNDS.
- **Font sheets:** Roblox can't import fonts, so `python tools/export_font_atlas.py <font folder>` makes image sheets in `assets/hud/` (local only) and writes `GlyphData.luau`. Upload changed sheets to the group with `tools/upload-group-assets.py` and put their ids in `src/shared/Guns/Hud/FontImages.luau`. Trial and free font zips are in River's Downloads: `KH-Interference-TRIAL.zip` and `PPFraktion-Free_for_personal_use_v1.1.zip`.
- **Arm animation:** `tools/export_arm_clips.py` runs in background Blender (`H:/blener/blender.exe`) on `H:/player models/M57 Arms Posed.blend` and `H:/player models/Energy Pistol Arms Posed.blend`, and overwrites the gun's `ArmClips/<Gun>.luau`. Its output path (`OUT`, line 6) still points at the old folder, `H:/rblxgame/src/shared/Guns/ArmClips/`; change it to `H:/SplitDeck` before the next export. Run it through the wrapper: `blender.exe -b <file> --python tools/arm_bg.py -- "M57"` or `"Energy Pistol"`. After every pistol export, run `python tools/resample_clip.py src/shared/Guns/ArmClips/EnergyPistol.luau <clip> 24 24.9 7 14` for `reload`, `reload2` and `reload3`. The M57 fps is 24.37, set in the export script.
- River's open Blender may hold unsaved work in `Marathon guns V3.blend`. Never touch it.
- Node isn't installed, so the brainstorming browser companion doesn't work. Mockups go in `.superpowers/` as plain HTML.
- **Kiro MCP:** Kiro can't write its own settings. The Blender and Roblox Studio MCP config is staged in `.superpowers/kiro-mcp.json`; River copies it to `~/.kiro/settings/mcp.json` and restarts Kiro. uv and the MCP for Blender addon are installed. Blender MCP drives whichever Blender window is open, so save `Marathon guns V3.blend` and open a blank file first.

## What's built

- Movement: sprint, slide, chain jumps, parry, and the server's cheat checks. Climbing was removed on 2026-11-07. `docs/specs/movement.md`.
- Guns, with first-person arms, reloads and sounds. Each of the M57 and pistol has 3 reload takes that differ only in position. `docs/specs/guns.md`.
- Abilities and the card core: 4 cards, fusion, Deck Power Rating, income, saves through ProfileStore. `docs/specs/cards.md`.
- HUD in River's fonts, using image text (`TypeLabel`). `docs/specs/hud.md`.
- The doc's palette across the game: `src/shared/Guns/Palette.luau`.
- Sounds: guns, hits, kills, low health, footsteps, jumps, menu music, selection. Roblox's default running sound is muted on every character. `docs/sound-list.md` has what's in and what's still needed.
- Title screen, with menu music, a visualizer and cursor parallax. `docs/specs/title-screen.md`.
- The Outpost hub, step 1: the place itself, built at server start by `src/server/Outpost/`. PLAY lands in its main hall. Lift doors in its east corridor go to the test room, and a terminal by the test room spawn comes back. The Outpost is a safe zone: no guns, cards or HUD. `docs/specs/outpost.md`.
- The player body: the low poly model, styled like the arms (`BodyStyle.luau`), in 12 fps stop-motion with jitter, a slide pose and weight (`BodyPose.luau`, `RemotePoses.client.luau`). A soldier body (attribute `SoldierRig`) uses the gun poses in `BodyPoses/` with `GunStance.luau` and `HeldGuns.luau` instead. The soldier model is `StarterCharacter` in the group's place: an invisible part for each R15 part, joined by Motor6Ds, with the mesh pieces welded on. The FBX files are group assets: SoldierBody 109394536713108, SoldierArms 129298333100302, PistolMagStandIn 137691897540108, ShellStandIn 99392044611539. SoldierBody's plain hand meshes exported at the origin, so they were moved onto the wrists by hand. The old body is `ServerStorage.StarterCharacterOld`. `GunModels.SoldierArms` is imported but not used yet: first person still uses `Arms` and the camera height hasn't moved. Only its root part collides with the world (`CharacterBody.server.luau`). `docs/specs/movement.md`.
- Not built: matches (Elimination and Tower). The agreed design is in `docs/specs/matches.md`.

## Where we are now

All the work above is merged to `main`. Nothing is half built.

**Confirmed in Play by River (2026-11-05):** the Outpost floor, textures and lamp shadows, the title screen (no stray menu copy, visualizer, parallax, music levels, PLAY `>`), the selection sound on click, and the jump sounds. All work.

**Known gaps:**
- Other players' footsteps and shots can't be heard. Roblox's default footsteps are muted and ours play only for the local player, and only your own shots make a sound.
- Sounds still to record and hook up are in `docs/sound-list.md`, among them landing, slide and parry. The M57's reload hit isn't aligned to the new assault reload sound.
- Fonts: River has the Pro downloads in `Downloads`. KH Interference's file still names itself TRIAL, and the titles and card monograms use it, so River needs to confirm the licence before publishing.
- If Studio says "We could not open the place [70756985983915]. Failed to fetch place info." again: it's a known 2026 Studio bug. Roblox staff suggest logging out of Studio, ending it in Task Manager and logging back in. River's group role is listed as "Member" (rank 1) and the group has no Owner role, which is worth checking in the group's settings if that doesn't work.
- A lag issue was noticed earlier and never diagnosed.
- The console shows `CardCoreRemotes.Snapshot` events with no listener. The likely cause is that the first snapshot fires before `Outpost.client.luau` connects its listener. Not verified.

- The Outpost UI: the nav, the sliding panel, Settings, Play, Loadout, Profile with the card index, clicking players, and comments (`docs/specs/outpost-ui.md`). River approved it in Play. Comments still need testing with two players, and the live filter, DataStores and reports need a live server. Play shows the queues as `SOON` until matches exist.
- Players can only pick Assault with the M57, or Marksman, for now. The B33, Rusher and Breacher stay in the gun data.
- Your own character leaves a faint glowing blur in the Outpost that only you can see.

- Packs and rebirths are built (`docs/specs/packs.md`), waiting on River's check in Play. The new wrappers were still in Roblox's review on 2026-11-07, and show blank until they pass. Before launch, River creates the Open All developer product and the Auto Open gamepass, puts their ids in `Config.luau`, and opens the group. Purchases, the favorite and the group check need a live game to prove.

**Next up:** serials, then the player market. The 1v1 map still waits. Outpost ambient sounds wait on River's rain, sea and hum loops. Phase 4 Matches is parked until gameplay looks, sounds and feels good. River decides what's next.
