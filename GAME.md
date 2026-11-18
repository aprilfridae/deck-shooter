# Split Deck

Written 2026-11-17 from the repo (docs, specs and `src/`), then checked against the open place in edit mode
(place 70756985983915, version 425). Not seen in Play. `(inferred)` marks anything not stated by River in the docs.

This file is the short agreement. The detail lives in `docs/specs/` (indexed by `docs/README.md`), the working
rules in `docs/HANDOFF.md` and `handoff.md`, and the numbers in the code. Where they differ: code beats spec,
spec beats this file, and all beat the old parent "Deck-Shooter Design Spec".

## One-line pitch
A fast first-person PvP shooter where you carry two guns and a three-card ability deck, and roll free card
packs in a social hub to build that deck.

## Pillars
1. Skill beats collection: a good player with a Field deck can beat a weaker one with a Prototype deck. Luck never affects combat.
2. Feel first: movement, gun handling, animation and sound are judged by River in Play, and matches wait until those feel good.
3. The server decides everything that matters: hits, health, ammo, cards, Credits, packs, trades.
4. Clean and readable (inferred): maps without clutter or z-fighting, a restrained six-colour palette, red only for threats and purchases.
5. Rolling and opening are free; Robux buys convenience only (inferred from `packs.md`).

## Core loop
- 30 seconds: move (sprint, slide, chain jump, wall jump, parry), shoot, use a card, get the kill, see the pop-ups and Credits land.
- Session: fight in the test room or a 1v1 map, go back to the Outpost, roll and open packs, fuse and edit the deck, check the market.
- Long term: cards earn Credits while you play; Credits buy rebirths; each rebirth raises luck; better pulls can be sold at auction for more Credits.
- Not observed in Play this session. Matches (the intended main loop) are not built.

## Player and devices
- Audience: not stated. Reference point is Black Ops style movement shooters (inferred).
- Primary device: PC. Phones and consoles come after PC; sprint speed was already lowered partly for phones.
- Session length: not stated.
- Players per server: 60 in the place's settings (not a stated decision). Competitive; planned queues are Elimination 1v1/2v2/3v3 and Tower 5v5.

## Progression and economy
Cards have a tier (Field, Redline, Prototype; `BlackSite` is Redline in code) and a variant (Base, Chromatic,
Redacted, Zero-Day). Tier changes ability stats; variant only changes income. Every pulled card has a serial.

| Item | Cost | Gives | Time to afford | Notes |
|---|---|---|---|---|
| Roll a pack | Free, one every 3s | 1 pack: Field 80%, Redline 16%, Prototype 3.98%, Zero-Day 0.02% | 3s | Auto roll unlocks by favouriting or joining the group; Outpost only |
| Open a pack | Free | 3 cards, mostly the pack's tier | - | Card odds in `Config.PackTierOdds` |
| Fuse to Redline | 5 Field copies (4 with a Catalyst) + 100 CR | 1 Redline | - | |
| Fuse to Prototype | 5 Redline copies (4 with a Catalyst) + 600 CR | 1 Prototype | - | |
| First rebirth | 25,000 CR, takes all Credits | +0.15 luck | 50 kills, or about 23 hours on the starter deck's 0.3 CR/s alone (computed, not tuned) | Each next one costs 2.5x; no limit; cards, deck and packs kept |
| Open All | 1,500 Robux per use | Opens the whole pile | - | Developer product, id 0 until River creates it |
| Auto Open | 100 Robux once | Opens 1 pack every 2s in the Outpost | - | Gamepass, id 0 until River creates it |

- Currencies: Credits only. Earned from card income (0.1 / 0.6 / 3.5 CR/s per Field / Redline / Prototype copy, x1.5 / 2.5 / 5 by variant, +10% set bonus, halved past 10 copies), kills (500, plus bonus lines 100 to 1,000, same victim pays once per 20s) and auction sales. Spent on fusion fees, rebirths and auction bids.
- Catalysts exist in the save and the fusion rule; nothing gives or shows them yet.
- Variant odds per card: Chromatic 1/50, Redacted 1/500, Zero-Day 1/5,000 (5% from a Prototype pack; guaranteed once in a Zero-Day pack).
- Player market: auctions with bids and optional Buy Now, no market cut, lengths of 1, 6 or 24 hours.
- Deck Power Rating: tier points 100 / 112 / 125 plus 3 per gun level. Gun upgrades wait until after launch.
- Monetisation stance: convenience only. `PolicyService` hides Open All where paid random items are restricted.
- All of these are "starting numbers to tune".

## Combat numbers
- Health 100, respawn 3s. Hip fire only, except the Longscope, which scopes.
- Classes players can pick: Assault (M57 + Energy Pistol) and Marksman (Longscope + Energy Pistol). Rusher (SMG), Breacher (Shotgun) and the B33 wait in the data.
- Cards (10, set_01): Phase Dash, Overclock, Aegis Shell, Switchback, Kickplate, Siphon, and since 2026-11-17 Flashpoint (blinding flash), Bulwark (giant card wall), Split (running decoy) and Rewind (back 3s, some health back). Starter deck: Phase Dash, Overclock, Siphon. A Prototype is about twice a Field. No card does damage.
- Movement: walk 15, sprint 18.5, slide start 31, speed limit 48 studs/s; gravity 75.

## Art direction
- Style guide: `brutalist-skill` (inferred: military-terminal HUD in image fonts, slanted plates and cut corners, heavy brutalist maps).
- Palette (`src/shared/Guns/Palette.luau`): Deep Navy 41,50,79; Signal Acid 194,254,11; Data Cyan 1,255,255; Field Green 89,180,29; Hazard Red 255,13,26; Bone 232,230,223; Zero-Day back 14,16,24.
- Tier colours: Field navy, Redline red, Prototype acid, Zero-Day cyan on near-black.
- Fonts: KH Interference and PP Fraktion, drawn as image sheets (`TypeLabel`). Licence for KH Interference still to confirm.
- Maps: teal and orange lights and accents, never green. Clean, no clutter. Hex brief: dystopian retro-futurism, heavy brutalism, oppressive and abandoned.
- Lighting in the place: `LightingStyle` Soft, global shadows off, ambient 0.5 grey, clock 11.2, brightness 1.98, `ColorGrading`, and `Bloom` at intensity 0. Zones set their own look at runtime; Relay has teal fog.
- Models: River's own (AK as the M57, Energy Pistol, lever-rifle Longscope, soldier body and arms), baked textures since 2026-11-16.

## Audio direction
- River records and supplies the sounds; they are group assets (`SoundIds.luau`, `GunSounds.luau`). Volume groups in `src/client/SoundGroups.luau`.
- In: guns, hits, kills (climbing with the streak), low health, footsteps, jumps, menu music and selection, pack openings, Outpost ambience, the radio (stand-in track).
- Missing: other players' footsteps and shots, landing, slide, parry, pack tear and card flip, new-card sounds. Full list in `docs/sound-list.md`.

## World and content list
All maps are built in code at server start (`src/server/Outpost/`), not stored as parts in the place. In edit
mode Workspace holds only `Scene`, a lone skinned mesh (50 bones, untextured) far from the origin; StarterGui,
SoundService and Teams are empty.
- In the place only: `ReplicatedStorage.GunModels` (M57, Energy Pistol, Longscope, B33, SMG, Shotgun, Arms, SoldierArms, Card, two stand-ins), `StarterPlayer.StarterCharacter` (the soldier, R15, `SoldierRig`), and backups in `ReplicatedStorage.GunModelsOld` and ServerStorage (`ModelBackups`, `StarterCharacterOld`, `LongscopeOld`, `LongscopeTextured`, `M57Old`, `EnergyPistolOld`).
- Outpost (hub, safe zone: no guns, cards or HUD): built, approved in Play.
- Test room (two dummies): built.
- Relay (1v1 map, two towers and a bridge): built as free play; latest pass not checked in Play.
- Hex (box 1v1 map): built with a first art pass; art pass not checked in Play.
- Matches (Elimination, Tower, 7 + 1 Tower arenas): planned, parked. `docs/specs/matches.md`.
- Guns: 3 in play (M57, Energy Pistol, Longscope); B33, SMG, Shotgun and three more pistols in data only.
- Cards: 10. Recon Pulse and Arc Mine were removed. The four newest have no card art or sounds yet.

## UI inventory
All UI is built in code by client scripts under `src/client/`; nothing is authored in StarterGui (inferred).
- Title screen: `TitleScreen.client.luau` - built, approved.
- Combat HUD, kill pop-ups, kill feed, hit markers: `Hud.client.luau`, `KillPopups.luau`, `KillFeed.client.luau` - built; feed seen with one player only.
- Outpost nav and sliding panel: `OutpostMenu.client.luau`, `NavButton.luau`, `MenuPanel.luau`, `PanelKit.luau` - built, approved.
- Pages: Play (`PlayPanel`, queues read `SOON`), Packs (`PacksPanel`), Loadout (`LoadoutPanel`), Profile with card index and comments (`ProfilePanel`, `CommentsPanel`), Market (`MarketPanel`, not seen in Play), Settings (`SettingsPanel`).
- Credits and rebirth line: `IncomeLine.luau`. Radio strip: `RadioHud.luau`.
- Cards: face, inspect in 3D, in hand, pack reveal (`CardFace`, `CardInspect`, `CardInHand`, `PullStage`, `PullReveal`).

## Technical notes
- Source of truth is this repo, synced to Studio by Rojo (`default.project.json`, port 34872). **Never edit scripts in Studio, and never export Studio scripts into `src/`.** Models, lighting and `StarterCharacter` live only in the group's place.
- Layout: `src/shared/{CardCore,Movement,Guns}` -> ReplicatedStorage; `src/server` -> `ServerScriptService.CardCoreServer`; `src/client` -> `StarterPlayerScripts.CardCoreClient`; `src/character/Health.server.luau`.
- Pattern: rules are pure modules in `src/shared`, tested with Lune (`lune run tests/run.luau`); client and server scripts are thin and are compiled, not tested.
- Data saved: ProfileStore `PlayerData_v1`, schema in `src/shared/CardCore/SaveData.luau`, version 6. Saves older than version 5 are wiped on load. Fields: credits, stacks, serials, market, deck, gunLevels, catalysts, class, rifle, settings, commentsOff, packs, rebirths, openAllCredits, receipts.
- Other stores: `SerialCounters_v1` (key `all`), `Auctions_v1`, memory store sorted map `Auctions_all`, `ProfileComments_v1`, `ProfileCommentReports_v1`.
- Remotes (folders in ReplicatedStorage, all validated on the server):
  - `GunRemotes`: Fire, Reload, Swap, SetLoadout (client to server); HitConfirm, Impacts, Shots, KillFeed, KillReward, DeathBurst (server to client).
  - `AbilityRemotes`: Use, TestDeck, Fx, Dash, Push.
  - `MovementRemotes`: Pose, Look, WallJump, Cards.
  - `CardCoreRemotes`: Snapshot, PackEvent, MarketNews (events); RemoteFunctions Fuse, SetDeck, GetProfile, comments and settings calls, GetSnapshot, Roll, OpenPack, Rebirth, SetAutoRoll, ClaimFavorite, CheckGroup, OpenAll, BuyAutoOpen, ListCard, PlaceBid, CancelListing, BrowseAuctions, AuctionInfo, MySerials, MyAuctions.
  - `OutpostRemotes`: Travel.
- Config modules: `src/shared/CardCore/Config.luau` (cards, economy, packs), `src/shared/Guns/GunConfig.luau`, `src/shared/Movement/MoveConfig.luau`, `src/shared/Guns/KillRewards.luau`. Full table in `docs/README.md`.
- Place: Fridae Studios group 237720778, universe 10774901448, place 70756985983915, private. `StreamingEnabled` off, first person locked, R15-shaped soldier rig.
- Known constraints: the market list is one memory store map (about 64 KB + 1 KB per player online). Audio only plays in group-owned experiences.

## Naming conventions
- Code names differ from display names: `M4` = M57 (River's AK), `AK47` = B33, `Sniper` = Longscope, `Pistol` = Energy Pistol, `BlackSite` = Redline. Repo and Rojo project are still `deck-shooter` / `DeckShooter`.
- Gun MeshParts: `<Group>_<Material>` with groups `Static_`, `Bolt_`, `Slide_`, `Mag_`, `Trigger_`, `Lever_`.
- Attributes and tags: `SoldierRig`, `PosedBody`, `GunId`, `PaysKill`, `ViewShift`; workspace debug attributes `PinDraw`, `KillFxSpeed`.
- DataStores end in `_v1`. Branches are `feature/<topic>`. Tests are `tests/<module>_spec.luau`, listed in `tests/run.luau`.

## Out of scope
- For now: matches and matchmaking, gun upgrades, mobile and console controls, bots, offline rolling.
- Never: committing `assets/`, place files or keys; touching `Marathon guns V3.blend`; green map lighting.

## Open questions
- `feature/kill-fx` and `feature/switchback-chain` have no pull request. Open and merge them?
- Audience, session length and players per server.
- Delete the backups (`GunModels.Arms`, `ReplicatedStorage.GunModelsOld`, `ServerStorage.StarterCharacterOld`, `LongscopeOld`, `ModelBackups`)? `GunModelsOld` replicates to every client.
- What is `Workspace.Scene` (a skinned mesh at 0, -4, -128), and should it be in the place?
- The soldier's `HipHeight` is still 2 (the handoff suggests about 2.3 if the feet sink).
- Is 60 players per server intended?
- Auto roll rewards a favourite, which Roblox's rules appear to ban. River accepted this on 2026-11-07; still the plan for launch?
- Open from code review: Kickplate pauses the movement guard for 3s; Siphon's slow is enforced by the slowed client.

## Decision log
Older decisions are in the specs and git history. Only the ones a new agent must not undo are repeated here.

| Date | Decision | Why |
|---|---|---|
| 2026-11-07 | Climbing removed; matches parked until gameplay feels good | River |
| 2026-11-07 | Maps stay clean: no clutter, no z-fighting | River's first look at Relay |
| 2026-11-10 | Sprint lowered to 18.5 (from 30) | River wants it less fast paced and playable on phones |
| 2026-11-11 | M57 body damage 14 (from 24) | River wanted a longer time to kill |
| 2026-11-11 | Saves before version 5 are wiped; every serial comes from a pull | Fresh start for the market |
| 2026-11-11 | Auctions: bids plus Buy Now, no cut, 1 / 6 / 24 hours | River |
| 2026-11-11 | Switchback, Kickplate, Siphon added; Recon Pulse removed; Prototype about twice Field | "higher rarity = better" |
| 2026-11-15 | Headshot disc and kill view snap removed from kill effects | River |
| 2026-11-17 | GAME.md written from the repo; Studio scripts not exported into `src/` | `src/` is the Rojo source, and an export would add a second copy in a different layout |
| 2026-11-17 | The assistant may press Play and playtest on its own | River: "you can self play test and work on the game by yourself" |
| 2026-11-17 | Four cards added (Flashpoint, Bulwark, Split, Rewind), none doing damage, each with its own hand move built from the flourish's pieces | River asked for more cards with first- and third-person animations; utility keeps "skill beats collection" |
| 2026-11-17 | A click that uses a card no longer fires the gun when it comes back | Found in the playtest: every card use cost a bullet |
| 2026-11-17 | Rojo wasn't syncing, so the repo's changes were copied into Studio by hand for the playtest | Shell commands needed approval overnight; Studio now matches the repo for these files, and Rojo will overwrite them with the same code |
| 2026-11-18 | The card grid shares cards evenly into full-width bands (10 = 5 + 5) and scrolls; the Profile's owned count moved to the header | River: the chooser couldn't reach the new cards, and the short last band left empty space |
| 2026-11-18 | Fusing gets a button under a card held up on your own Profile (5 copies + the fee, a second press when variants would be spent) | The server's Fuse had no way in from the game. The index is the only page with copy counts; this reverses outpost-ui's "fusion stays out of Profile", River can move it |
| 2026-11-18 | Split's monogram is SL | SP is already Siphon's, and every monogram must be different |
| 2026-11-18 | A roll onto a full pile still uses the 3s wait; Open All is hidden until the policy check answers | The full pile let auto roll skip the wait; an unanswered policy check let Open All be bought where it may be restricted |
| 2026-11-18 | Kickplate's launch is checked against its own speed instead of pausing the movement guard; Siphon's client-side slow is accepted | The 3s pause let a cheat teleport anywhere (tested: now caught). Ignoring a slow gains nothing past the guard's normal limit, and scaling the limit would strike honest slowed dashes |
| 2026-11-18 | Auto Open keeps opening behind the title screen, but its rare reveals only show in the Outpost with the menu up | Opening is idle progress and the cards reach the index; a card popping up over the title or in the test room was the problem |
| 2026-11-18 | Siphon gets a jagged bolt and a drain tether; Kickplate punches its own card out of the surface with a ring, lines, sparks and dust | They were the last cards with placeholder effects. Flat neon like the HUD; the Kickplate light kept small and pale because pure acid washed rooms green |
