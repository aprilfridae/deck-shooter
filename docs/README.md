# Split Deck docs

Split Deck is a Roblox PvP shooter: fast Black Ops style movement, 2 guns plus a 3-card ability deck, and a social hub for rolling card packs. It's made by River with the Fridae Studios group. Older docs call it Deck-Shooter, and the repo (`aprilfridae/deck-shooter`) and Rojo project (`DeckShooter`) still use that name.

**New here?** Read `HANDOFF.md` first. It covers how River works, the tools, and where things stand. Then read the spec for whatever you're changing.

## What's here

| Doc | Covers | Status |
| --- | --- | --- |
| [`HANDOFF.md`](HANDOFF.md) | Working with River, tools and setup, what's built, known gaps, what's next | Kept current every session |
| [`specs/movement.md`](specs/movement.md) | Moves, camera, keys, movement cheat checks, the soldier body's third-person poses | Built; the soldier swap waits on River's check in Play |
| [`specs/guns.md`](specs/guns.md) | Classes, gun stats, recoil, ammo, hit checking, health, first-person arms, test dummies | Built |
| [`specs/cards.md`](specs/cards.md) | The 4 ability cards, tiers, fusion, variants, income, Deck Power Rating, saves, card remotes | Built |
| [`specs/card-art.md`](specs/card-art.md) | How cards look, rarities, variants, inspecting a card, serial numbers | Menus and inspect built; card in hand and serials aren't |
| [`specs/packs.md`](specs/packs.md) | Rolling, opening, auto roll, Robux purchases, rebirths, luck and the packs menu | Built, waiting on River's check in Play |
| [`specs/hud.md`](specs/hud.md) | The HUD and the image font system | Built, with trial fonts |
| [`specs/title-screen.md`](specs/title-screen.md) | The title screen and menu music | Built |
| [`specs/outpost.md`](specs/outpost.md) | The Outpost hub, zones, travel, the safe zone | The place is built; the player market isn't |
| [`specs/serials.md`](specs/serials.md) | Real serial numbers for every pulled card, and the fresh start | Agreed, not built. First piece of the player market |
| [`specs/outpost-ui.md`](specs/outpost-ui.md) | The Outpost menus: Play, Packs, Loadout, Profile, comments and Settings | Built |
| [`specs/matches.md`](specs/matches.md) | Elimination and Tower modes, rounds, arenas | Planned, not built |
| [`specs/relay.md`](specs/relay.md) | Relay, the 1v1 map: two fog towers, a bridge, the undercity | Built as a free-play zone, not checked in Play |
| [`specs/hex.md`](specs/hex.md) | Hex, the box 1v1 map: a ring of six walls with shooting holes, spawn cover and corner ramps | Built with a first art pass; the art pass is not checked in Play |
| [`specs/radio.md`](specs/radio.md) | The radio: a personal playlist of River's tracks with a HUD strip and visualizer | Built, not seen in Play; only a stand-in track so far |
| [`sound-list.md`](sound-list.md) | Sounds in the game and sounds still needed | Kept current |

Other places with rules:

- `AGENTS.md` and `.kiro/steering/push-every-session.md`: every coding session ends with a pull request and a place build.
- `README.md` in the repo root: setting up a computer, Rojo, tests and builds.

## The parent design spec

"Deck-Shooter Design Spec" (rev 13) is a Claude artifact at https://claude.ai/artifact/P6cgJtFzpNRJJcx53PMoMH. It isn't in the repo and can't be fetched without River's login. It covers the whole game: the palette, the economy and market, matchmaking, and the roadmap.

The specs here win wherever the two differ. Known differences:

- The game is Split Deck, not Deck-Shooter. The fonts are KH Interference and PP Fraktion, not Michroma and Roboto Mono.
- Headshots follow each gun (2x, or an instant kill on the B33 and Longscope), not one multiplier.
- Classes, the Assault rifle choice, and the Elimination and Tower modes are added.
- Arc Mine is removed, leaving 4 cards. Phase Dash covers 13 / 14.5 / 16 studs, Aegis Shell's Prototype duration is 3.75s, and Overclock has no perk.
- Deck Power Rating uses tier points of 100 / 112 / 125.
- Gun upgrades wait until after launch.
- Reload times are much shorter: 0.985s for the M57 and B33, 0.964s for the Energy Pistol, 1.714s for the Longscope.
- The hub is the Outpost.

## Where the numbers live

The specs explain the design. The code holds the actual values, so check it before relying on a number.

| What | File |
| --- | --- |
| Movement and its speed limits | `src/shared/Movement/MoveConfig.luau`. The cheat check's timings are at the top of `src/server/MovementGuard.server.luau`. |
| Guns and classes | `src/shared/Guns/GunConfig.luau` |
| Hit checking | `src/shared/Guns/ShotRequest.luau`, `Hitbox.luau`, `History.luau`, and the top of `src/server/GunServer.server.luau` |
| Cards | `src/shared/CardCore/Cards.luau` |
| Fusion, income, DPR, card ability values, save limits, pack odds, rebirth prices | `src/shared/CardCore/Config.luau` |
| Colours | `src/shared/Guns/Palette.luau` |
| Sounds | `src/shared/Guns/GunSounds.luau`, with ids in `SoundIds.luau` |
| Outpost textures | `src/shared/Guns/OutpostAssets.luau` |
| Font sheets | `src/shared/Guns/Hud/GlyphData.luau` (generated) and `FontImages.luau` (ids) |
| HUD, title screen and Outpost layout | The constants at the top of `Hud.client.luau`, `TitleScreen.client.luau` and `src/server/Outpost/Map.luau` |
| Relay map layout and its fog | The constants at the top of `src/server/Outpost/Relay.luau`; `RELAY_LIGHTING` and `relayEffects` in `src/client/Outpost.client.luau` |

## Words

| Word | Meaning |
| --- | --- |
| Tier | A card's level: Field, Redline, Prototype (`Field`, `BlackSite`, `Prototype` in code) |
| Variant | A copy's finish, which only changes income: Base, Chromatic, Redacted, Zero-Day |
| Fusion | Turning 5 copies (4 with a Catalyst) into 1 copy of the next tier |
| DPR | Deck Power Rating, from the deck's tiers and gun levels only |
| Credits | The currency cards earn while you play |
| Soldier | The player body (attribute `SoldierRig`), which replaced the old low poly body and arms |
| Zone | Where a player is: `Outpost` (safe, no combat), `TestRoom`, `Relay` or `Hex` (the 1v1 maps) |
| Test room | The grey room for trying guns and cards, with a grey dummy and a soldier dummy. Reached from the Outpost. |
| Palette | Deep Navy, Signal Acid, Data Cyan, Field Green, Hazard Red and Bone. Red is for threats and purchases only. |
| Group | Fridae Studios (group 237720778), which owns the experience and every asset |

## Keeping the docs useful

- One spec per system in `specs/`, named by topic. Each starts with a status line (built, partly built or planned) and the date it was last checked against the code.
- Say plainly what isn't built and what's unverified.
- A change that alters a behaviour or number a spec states updates the spec in the same pull request.
- Implementation plans are temporary. Put them in `plans/` while the work is in progress, move any lasting decisions into the spec, and delete the plan in the pull request that finishes the work.
- Mockups go in `.superpowers/` as plain HTML. That folder is git-ignored and stays local.
- Docs follow the repo's rule: code and text only, never assets, place files or API keys.
- Older specs and the finished plans (movement, guns, abilities, card core, HUD, title screen) are in git history. For example: `git show a3b8f85:docs/superpowers/plans/2026-11-03-card-core.md`.
