# Split Deck: project handoff

Read this first, then continue from "Where we are now". Last updated 2026-11-07 (evening).

## The project

Split Deck is a Roblox PvP shooter: fast Black Ops style movement, 2 guns plus a 3-card ability deck, and a social hub for rolling card packs. It was called Deck-Shooter in older docs. The repo (`aprilfridae/deck-shooter`, default branch `main`) and the Rojo project (`DeckShooter`) still use the old name.

- **Docs:** `docs/README.md` indexes every design spec in `docs/specs/`, lists where they differ from the parent spec, and says which file holds each number. Read the spec for whatever you're changing, and update it in the same pull request when a behaviour or number it states changes.
- **Task board:** Trello board "Split Deck" at https://trello.com/b/AqV7SmvQ/split-deck (River's riversmusz account). It tracks what's left: the soldier swap steps, every missing sound, features to build, bugs, and what waits on River. Move cards to done when work lands. River's older board, river-wip, isn't visible to the connected account.
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
- **Tests:** `$env:PATH = "$HOME\.rokit\bin;$env:PATH"; lune run tests/run.luau` in PowerShell (546 passing). A new `*_spec.luau` goes in the `listed` table (`name_spec = true,`) and gets a `require` line in `tests/run.luau`, or the run fails. Specs for modules using `CFrame` load them through `@lune/luau` with Lune's roblox types; see `tests/soldierpose_spec.luau`. The tests don't load client or server scripts, so a syntax error there slips through: compile every file under `src/` with `luau.compile` from `@lune/luau` before pushing. Compiling doesn't catch undefined globals, so check requires by hand.
- **Rojo:** `rojo serve`, port 34872. If Studio reopens, River reconnects the plugin, in edit mode (connecting during Play fails with "Http requests can only be executed by game server"). A running server misses new `default.project.json` mappings, so put new modules in folders already mapped, such as `src/shared/Guns/` and `src/client/`. Rojo crashes on some branch switches. The server doesn't survive a restart of the computer; check it's listening on 34872 when River says changes aren't showing up. Code synced by Rojo only runs in the next Play, so River restarts Play after a change.
- **Collaborators and the group:** the game now lives in the Fridae Studios group (group 237720778, owner River), experience "SplitDeck" (universe 10774901448, root place 70756985983915, private). The repo is code only; README.md has the setup. The group's place holds `ReplicatedStorage.GunModels` (guns, `Arms`, `Card`), `StarterPlayer.StarterCharacter` (the low poly player, made with Studio's auto-rigger from `H:player modelsowpoly.glb`, with its root lowered so it stands 3 studs above the feet like the default rig, and `AutomaticScalingEnabled` off because scaling puts the root back; `Movement.client.luau` takes the camera down 0.5 to match), lighting with its `ColorGrading` and `Bloom`, and the place settings; Rojo leaves those alone. Sounds, Outpost textures and font sheets are group assets (ids in `SoundIds.luau`, `OutpostAssets.luau`, `Hud/FontImages.luau`, uploaded 2026-11-05). Uploaded audio only plays in group-owned experiences. `tools/upload-group-assets.py` uploads new files with the group API key from `ROBLOX_GROUP_API_KEY`. Local working copies stay in `assets/`, which git ignores. The older user-owned assets and experience (universe 10774583287) still exist on River's account but aren't used.
- **GitHub CLI and builds:** `gh` isn't logged in on River's machine, but Git Credential Manager holds River's GitHub token. For a command that needs `gh`, read it with `git credential fill` and pass it as `GH_TOKEN` for that command only; never print or save it. `tools/build-place.luau` builds the code with Rojo and adds the place content. With a saved copy of the group's place as its argument it keeps that place and swaps in the code. Without one it uses `assets/models/` (local exports of `GunModels`, `ColorGrading`, `Bloom`) and the lighting values in the script. Downloading the group's place through Open Cloud (`tools/download-place.py`) needs the Legacy Asset permission, which Roblox refuses on group-owned keys; River's user key works. Roblox serves the place gzipped. After a publish the plain download can keep serving an old copy, as it did on 2026-11-06, so pass the version (`game.PlaceVersion` in Studio) as a second argument and check `StarterPlayer.StarterCharacter` is in the file.
- **Roblox API keys:** both are saved as Windows user environment variables on River's machine, never in the repo. `ROBLOX_API_KEY` is River's user key ("for Claude"), with the Legacy Asset permission, for `tools/download-place.py`. `ROBLOX_GROUP_API_KEY` is the Fridae Studios group key ("Fridae API"), for `tools/upload-group-assets.py`. The group key can't download the place: Roblox answered "Scope not authorized" on 2026-11-05. It can also publish places, delete data stores and ban players, so use it only for uploads unless River says otherwise. A shell started before a key was saved won't see it; read it with `[Environment]::GetEnvironmentVariable('ROBLOX_API_KEY', 'User')`.
- **Local asset copies:** checking out a commit from before 2026-11-05's asset removal, then back, deletes the local `assets/` copies. `git restore --source=e63ef3f --worktree -- assets` brings them back without staging them.
- **Studio MCP without Kiro's config:** Kiro can talk to Studio through `%LOCALAPPDATA%\Roblox\Versions\<version>\StudioMCP.exe` over stdio, using a small Python MCP client. `execute_luau` replies are cut off at about 100k characters, so large exports are kept in `_G` and read back in chunks. `SerializationService:SerializeInstancesAsync` makes `.rbxm` bytes. Studio blocks reading `Lighting.Technology` from there.
- **Sounds:** River's source takes are prepared with `tools/pad-sounds.py` into `assets/sounds/` (local only), then uploaded to the group; `GunSounds.luau` lists them and errors at load if one has no id in `SoundIds.luau`. Roblox caches sounds by id, so a changed sound gets a new upload and id. Strip extra WAV chunks before uploading; they caused a click once.
- **River's sound folders:** `E:\sound effects for game\`, with GUN RELOAD, MOVEMENT SOUNDS, MENU MUSIC and MENU SOUNDS.
- **Font sheets:** Roblox can't import fonts, so `python tools/export_font_atlas.py <font folder>` makes image sheets in `assets/hud/` (local only) and writes `GlyphData.luau`. Upload changed sheets to the group with `tools/upload-group-assets.py` and put their ids in `src/shared/Guns/Hud/FontImages.luau`. Trial and free font zips are in River's Downloads: `KH-Interference-TRIAL.zip` and `PPFraktion-Free_for_personal_use_v1.1.zip`.
- **Arm animation:** `tools/export_arm_clips.py` runs in background Blender (`H:/blener/blender.exe`) on `H:/player models/M57 Arms Posed.blend` and `H:/player models/Energy Pistol Arms Posed.blend`, and overwrites the gun's `ArmClips/<Gun>.luau`. Run it through the wrapper: `blender.exe -b <file> --python tools/arm_bg.py -- "M57"` or `"Energy Pistol"`. After every pistol export, run `python tools/resample_clip.py src/shared/Guns/ArmClips/EnergyPistol.luau <clip> 24 24.9 7 14` for `reload`, `reload2` and `reload3`. The M57 fps is 24.37, set in the export script.
- River's open Blender may hold unsaved work in `Marathon guns V3.blend`. Never touch it.
- Node isn't installed, so the brainstorming browser companion doesn't work. Mockups go in `.superpowers/` as plain HTML.
- **Kiro MCP:** Kiro can't write its own settings. The Blender and Roblox Studio MCP config is staged in `.superpowers/kiro-mcp.json`; River copies it to `~/.kiro/settings/mcp.json` and restarts Kiro. uv and the MCP for Blender addon are installed. Blender MCP drives whichever Blender window is open, so save `Marathon guns V3.blend` and open a blank file first.

## What's built

- Movement: sprint, slide, chain jumps, parry, and the server's cheat checks. Climbing was removed on 2026-11-07. `docs/specs/movement.md`.
- Guns, with first-person arms, reloads and sounds. Each of the M57 and pistol has 3 reload takes that differ only in position. The test room has two targets: a plain grey dummy and a soldier dummy holding the M57. `docs/specs/guns.md`.
- Abilities and the card core: 4 cards, fusion, Deck Power Rating, income, saves through ProfileStore. `docs/specs/cards.md`.
- Packs and rebirths (`docs/specs/packs.md`), with the reworked pack opening River approved: nav fades out and back, the 3D pack tears down its side, three cards flip in 3D, and a burst in the pack's colours scales with rarity (`PullStage.luau`, `PullMotion.luau`, `PullParticles.luau`, `PullFx.luau`).
- HUD in River's fonts, using image text (`TypeLabel`). `docs/specs/hud.md`.
- The doc's palette across the game: `src/shared/Guns/Palette.luau`.
- Sounds: guns, hits, kills, low health, footsteps, jumps, menu music, selection. Roblox's default running sound is muted on every character. `docs/sound-list.md` has what's in and what's still needed.
- Title screen, with menu music, a visualizer and cursor parallax. `docs/specs/title-screen.md`.
- The Outpost hub: the place itself, built at server start by `src/server/Outpost/`. PLAY lands in its main hall. Lift doors in its east corridor go to the test room, and a terminal by the test room spawn comes back. The Outpost is a safe zone: no guns, cards or HUD. `docs/specs/outpost.md`.
- The Outpost UI: the nav, the sliding panel, Settings, Play, Loadout, Profile with the card index, clicking players, and comments (`docs/specs/outpost-ui.md`). River approved it in Play. Play shows the queues as `SOON` until matches exist. Players can only pick Assault with the M57, or Marksman, for now.
- The player body is the soldier (`StarterCharacter` in the group's place, attribute `SoldierRig`): an invisible part for each R15 part, joined by Motor6Ds, with SoldierBody's meshes welded on. Third person uses the gun poses in `src/shared/Movement/BodyPoses/`, picked by `GunStance.luau`, with the gun placed by `HeldGuns.luau`. Bodies move in 12 fps stop-motion and don't jitter; only the first-person arms jitter. First person shows `GunModels.SoldierArms`, posed by `SoldierPose.luau` from the old arm clips, so clip timing is unchanged. Hitboxes come in two sizes, soldier and plain Roblox body (`Hitbox.shapes`). Only the root part collides with the world (`CharacterBody.server.luau`). `docs/specs/movement.md` and `docs/specs/guns.md`.
- The FBX files are group assets: SoldierBody 109394536713108, SoldierArms 129298333100302, PistolMagStandIn 137691897540108, ShellStandIn 99392044611539. The old body is `ServerStorage.StarterCharacterOld` and the old arms are `GunModels.Arms`, kept as backups.
- Not built: matches (Elimination and Tower). The agreed design is in `docs/specs/matches.md`.

## Where we are now

**Branch:** `feature/soldier-first-person`, pushed, not merged. `main` has everything else. Latest good release: `build-2026-11-07-0233` (packs and gun pose code, no soldier). `build-2026-11-07-0232` was a mistake and its notes say so.

**The soldier swap is half done.** River asked to replace the old body and arms with the soldier. On 2026-11-07 River and their brother played it together in Team Test, which turned up these, all fixed on the branch and synced through Rojo but **not yet confirmed in Play**:

- Sliding and looking down showed a second gun on the ground: your own third-person gun showed mid-slide. It now always hides in locked first person.
- Other players' bodies held the gun over their heads: our pose script missed their joints, which arrive over the network after the parts, so Roblox's default idle animation bent the soldier rig. It now waits for the body and keeps collecting joints.
- Headshots on the grey dummy stopped counting (no headshot sound): the taller soldier hitbox was used for every body. Each target now gets its own size.
- Added the soldier dummy with the M57, and removed the jitter from every third-person body.

**Next steps, in order:**

1. River restarts Team Test with their brother and checks: no gun on the floor mid-slide; other players and the soldier dummy hold the gun in front of them, not overhead; poses change with walk, sprint, slide, jump and reload; headshots on both dummies play the headshot sound; nobody jitters in third person; hands sit on all six guns in first person; elbows don't cross the screen in reloads; the taller view doesn't clip low ceilings or doorways. If a body still looks wrong, read its Motor6D `Transform`s on the Client while River is in Play: a pose file's elbow only bends about X, so anything else means our poses aren't applied.
2. Out of Play, set `StarterPlayer.StarterCharacter`'s Humanoid `HipHeight` to about 2.3. The soldier's root is 3.315 above its feet and the Humanoid still has 2, so the feet probably sink about 0.3.
3. River publishes the place (File > Publish to Roblox). **The soldier exists only in River's Team Create session, not in a published version.** The group place was still version 52 without it. A build made before this has no soldier.
4. Merge the branch through a pull request, then build from the published place. Pass the new version to `tools/download-place.py` and check `StarterCharacter` has the `SoldierRig` attribute before releasing.
5. Once River is happy, ask whether to delete the backups `GunModels.Arms` and `ServerStorage.StarterCharacterOld`.

**How the soldier fits together (for fixes):**

- `StarterPlayer.StarterCharacter` isn't in StarterPlayer while the game runs, so the soldier dummy is copied from the first player who spawns as the soldier (`TargetDummy.server.luau`).
- Bodies with no player are posed when tagged `PosedBody`, with their gun in a `GunId` attribute on the model (`RemotePoses.client.luau`).
- `SoldierPose.luau` lines the soldier's hand up with the old clips' palm using the knuckles, copies each finger bone's direction, and bends the arm to reach. Guns without a clip (B33, SMG, Longscope, Shotgun) use `SoldierPose.palm` from their grips and the M57's idle fingers. Shoulders sit at `SHOULDERS` in camera space and slide forward if a hand is out of reach, so that's the tuning point if the arms look wrong. The soldier's meshes still get the cyan glow Highlight, as the old arms did.
- Camera: `BODY_CAMERA` is (0, 0.94, -0.5), the eye bar's height. The manifest's `firstPersonCameraFromHead` was not used, because it lands on top of the head. The camera is 0.5 forward rather than the bar's 0.99 to stay out of walls.
- Importing again, if the Team Create copy is lost: the source files are in River's `Downloads`: `soldier_manifest.json`, `ShellStandIn.fbx`, `PistolMagStandIn.fbx`; SoldierBody and SoldierArms are the group assets above. FBX meshes arrive turned 180 degrees about Y and raised 5.009, so the rest position is `(-x, y - 5.009, -z)` with `CFrame.Angles(0, math.pi, 0)`. SoldierBody's plain hands exported at the origin and were moved onto the wrists by hand. `StarterCharacter` has the old HRP (PivotOffset reset), Humanoid and Animate, 15 invisible parts, 15 Motor6Ds built from `BodyPoses/Empty.luau`'s `rig` (Root C0 raised by rootDrop 2.009), and SoldierBody's 65 meshes welded on, eye Neon, the rest SmoothPlastic. `GunModels` has `SoldierArms` (84 anchored meshes at their rest root-space positions), `PistolMagStandIn` and `ShellStandIn`. `SoldierArmsData.luau` is generated by `tools/build_soldier_arms.py`.
- Not done on purpose: first-person clips were not rebuilt from the new poses. `charactermodelandposes.blend` in `Downloads` has `FP_*` poses for the pistol only and no finger bones, and the `SplitDeck_Poses_<Gun>.blend` files `tools/export_body_poses.py` needs have never turned up. Its embedded `posekit_*.py` scripts are the pose generator. Gun size in first person stays as it was, so the Blender scale (4.2) is third person only.
- Unused: `ShellStandIn`. The shotgun reload shows no shell and `HeldGuns.luau` doesn't read the poses' `shell`.

**Testing with two people:** both must be in the same Team Test session. One starts it (Test > Team Test > Start), the other joins it from the same menu. Starting separately makes separate servers, and in the live game separate Play clicks can too.

**The other agent:** third-person gun poses came from another agent's `feature/gun-stances`, merged as PR 39. That agent's GitHub account keeps getting banned, which hides its pull requests: `gh pr create` then says one already exists. Push the same commits under a new branch name and open the pull request from there.

## Known gaps

- Other players' footsteps and shots can't be heard. Roblox's default footsteps are muted and ours play only for the local player, and only your own shots make a sound.
- Sounds still to record and hook up are in `docs/sound-list.md`, among them landing, slide, parry, and the pack tear and card flip. The M57's reload hit isn't aligned to the new assault reload sound.
- Fonts: River has the Pro downloads in `Downloads`. KH Interference's file still names itself TRIAL, and the titles and card monograms use it, so River needs to confirm the licence before publishing.
- Packs, waiting on a live game: purchases, the favourite and the group check. The new wrappers were still in Roblox's review on 2026-11-07 and show blank until they pass. Before launch, River creates the Open All developer product and the Auto Open gamepass, puts their ids in `Config.luau`, and opens the group.
- Smaller pack loose ends: a full pile lets auto roll skip the wait on other rarities; a receipt during a rejoin may wait for the next join; the receipt is recorded before the payout; Auto Open runs behind the title screen; a reveal can land in the test room; the group check after leaving; `OPEN ALL` isn't blocked until the policy check; and the auto loop has no pcall.
- Comments need testing with two players, and the live filter, DataStores and reports need a live server.
- Your own character leaves a faint glowing blur in the Outpost that only you can see.
- A lag issue was noticed earlier and never diagnosed.
- The console shows `CardCoreRemotes.Snapshot` events with no listener. The likely cause is that the first snapshot fires before `Outpost.client.luau` connects its listener. Not verified.
- If Studio says "We could not open the place [70756985983915]. Failed to fetch place info." again: it's a known 2026 Studio bug. Roblox staff suggest logging out of Studio, ending it in Task Manager and logging back in. River's group role is listed as "Member" (rank 1) and the group has no Owner role, which is worth checking in the group's settings if that doesn't work.

**Confirmed in Play by River:** the Outpost floor, textures and lamp shadows, the title screen, the selection and jump sounds (2026-11-05); and later the Outpost UI and the pack opening.

## Next up

Finish the soldier swap (above). After that: serials, then the player market. The 1v1 map still waits. Outpost ambient sounds wait on River's rain, sea and hum loops. Matches are parked until gameplay looks, sounds and feels good. River decides what's next.

## Practical notes

- Shells may start in `H:\rblxgame`, which is retired, so `cd` to `H:\SplitDeck` first.
- Use `set -e` in release scripts. A failed pull request step once carried on and published the wrong release.
- Use `--repo aprilfridae/deck-shooter` with `gh`. Blender is `H:/blener/blender.exe`. Open downloaded blends with `--disable-autoexec`.
- Studio's Edit data model is unavailable during Play, but Server and Client can still be read through Studio MCP. Reading is fine; never start Play or edit scripts through it.
