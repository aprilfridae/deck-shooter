# Split Deck: handoff, 2026-11-15

For whoever picks this up next. It covers where the work stands today. The long-lived setup notes are in `docs/HANDOFF.md` (last updated 2026-11-07, so its "Where we are now" is behind this file), and every design spec is in `docs/specs/`, indexed by `docs/README.md`.

## The project in one paragraph

Split Deck is a Roblox PvP shooter: fast movement, two guns plus a three-card ability deck, and a hub (the Outpost) for rolling card packs. River's working copy is `H:\SplitDeck`. The repo is `aprilfridae/deck-shooter`, default branch `main`, code only. The game lives in the Fridae Studios group, place 70756985983915. Code reaches Studio through Rojo (`rojo serve`, port 34872), never by editing scripts in Studio.

## Working with River

- River is not a coder and uses they/them. Casual tone. Keep replies short and say plainly what is unverified.
- River judges feel, timing and animation. Make the change they ask for; don't second-guess it.
- Maps keep teal and orange lights and accents, never green.
- Never commit `assets/`, place files or API keys. Never print or save the GitHub token or Roblox keys. The group API key (`ROBLOX_GROUP_API_KEY`) is for uploads only.
- Never touch `Marathon guns V3.blend`.
- Every coding session ends with a pull request into `main` and a place build released on GitHub. Merge only when River says to, in so many words.
- Publishing the place to Roblox is River's call.
- **Play testing:** the old rule was that River does all of it. On 2026-11-12 River said the assistant may press Play and capture the screen itself to tune the pull-out animations. Ask before assuming that covers other work.

## Where the code stands

- `main` has everything through pull request #58 (Market page, the Outpost and HUD redesign, the kill feed, the Switchback, Kickplate and Siphon cards). Released as `build-2026-11-12-0021`.
- **Branch `feature/switchback-chain` is 31 commits ahead of `main`, pushed, with no pull request yet.** The working tree is clean. River said "nice dude looks good" about the last piece, and was asked whether to open the pull request but hasn't answered.
- Pull request #41 (`feature/view-clips`) is still open from 2026-11-07 and is not part of this work.
- Tests: `lune run tests/run.luau`, 790 passing. Also compile every file under `src/` before pushing (the tests don't load client or server scripts).
- `rojo serve` was running as a background task and has stopped. Start it again in `H:\SplitDeck` before testing, and have River reconnect the plugin in edit mode.

## What is on the branch

All of it is written up in `docs/specs/cards.md` and `docs/specs/guns.md` ("Pull-out animations").

**Switchback's throw.** The card is thrown in first person, overhand, and the same card carries on into the world from the hand, turning blue and see-through with a trail. The left hand holding the deck moves out of the way. Files: `src/shared/Guns/CardFlourish.luau` (`CardFlourish.throw`), `src/client/CardThrowFx.luau`, `src/shared/CardCore/CardAim.luau`, `src/client/GunView.luau`, `src/server/AbilityServer.server.luau`.

**Pull-out animations**, played whenever a gun comes into the hands.

- Pistol and rifle keys are in `src/shared/Guns/GunDraw.luau` (pure numbers, tested in `tests/gundraw_spec.luau`). `GunView.luau` applies them.
- **Energy Pistol:** comes up to the middle, turned at the right wrist (`GunDraw.wrist`). The left hand goes over the back of the slide (`DRAW_SLAPS` in `GunView.luau`), pulls it back and lets go. The model's `Slide_` parts really move (`SLIDE_TRAVEL`).
- **M57 (River calls it the AK):** held up and to the left while the bolt is racked. The right hand comes over the charging knob palm down, fingers curled over it, thumb under (`ON_KNOB` and `AkReload.rack` in `src/shared/Guns/AkReload.luau`, `KNOB_FINGERS` in `GunView.luau`). The reload uses the same hand move. Measured in Play: no part of the hand is inside the receiver.
- **Longscope (the sniper):** keyed like its reload, in `KEYED_DRAWS` in `GunView.luau`. The right hand hauls it over the right shoulder and down, the left hand waits in place and catches the fore-end, then the lever is cocked.
- **For looking at a pull-out:** in Studio, set the number attribute `PinDraw` on `workspace` to hold every pull-out at that many seconds in. Clear it afterwards. To reach the guns: title screen PLAY, Outpost PLAY, TEST room. Key 1 is the primary, 2 the pistol, B cycles class (Marksman has the Longscope).

## Not verified

- The Longscope pull-out's last nudge (path moved further right) was not looked at after the change. River then said it looks good.
- Every pull-out was checked frozen at a few moments, not at full speed. River has judged the feel themself.
- Two players at once: Switchback swapping a real player, Siphon slowing one, the kill feed for others, Market bidding.
- Real DataStore and MemoryStore calls (Studio API access was off).
- Moderation of the uploaded HUD images.

## Open items

- Open the pull request for `feature/switchback-chain`, merge on River's word, and release a build (`python tools/download-place.py build/base.rbxl`, `lune run tools/build-place build/base.rbxl`, then `gh release create build-YYYY-MM-DD-HHMM build/SplitDeck.rbxl --target main`).
- Rifles other than the M57 only get the gun's tug in their pull-out, no hand on a bolt. The SMG and shotgun use the plain rifle draw.
- Other players don't see pull-outs; they are first person only.
- Left open from the code review of the new cards: Kickplate pauses the anti-cheat guard for 3 seconds, Siphon's slow is enforced on the client, and the nav doesn't rebuild on a window resize.
- The new cards' effects and sounds are placeholders.
- Older: third-person reloads for the SMG and shotgun, body animations.
- River asked the assistant to look at their Discord messages and then stopped it. Nothing was read. There is no Discord connector set up.

## How edits have been made

Small Python scripts that replace exact strings and assert each appears once, kept outside the repo. Image assets are baked with the Python tools in `tools/`, uploaded with `python tools/upload-group-assets.py`, and their ids put in Luau modules. Commits end with a `Co-Authored-By` line for the assistant.
