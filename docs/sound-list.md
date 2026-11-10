# Sound list

What the game already plays and what it still needs. Checked against the code on 2026-11-07.

## Making and adding a sound

- **Names:** use the names below. A sound with several takes adds `-1`, `-2` and so on. A changed version of a sound that's already in the game gets a new name with a version (`reload-assault-v2.wav`), because Roblox caches sounds by id.
- **Gunshots:** 30 stereo takes per gun, exported to `E:\sound effects for game\GUN VARIATIONS\GUN VARIATIONS\<GUN>\<GUN> (<n>).wav`. `python tools/pad-sounds.py` adds 20ms of silence to the front of each take, which keeps late shots on the beat, strips extra WAV chunks, and writes `assets/sounds/gun-<gun>-<n>.wav`. Shots can be any length, because each one rings out under the ones after it.
- **Other sounds:** go in River's folders under `E:\sound effects for game\`. Strip extra WAV chunks before uploading; they caused a click once.
- **Uploading:** every sound is uploaded to the Fridae Studios group with `tools/upload-group-assets.py`, and its id goes in `src/shared/Guns/SoundIds.luau`. Uploaded audio only plays in the group's experiences. `GunSounds.luau` errors at load if it names a sound with no id. If uploads start failing, check the key's permissions and Roblox's upload limit; the script stops after three failures in a row.
- **Mono and stereo:** today every sound plays straight into your ears. "Mono" marks sounds that should come from a place in the world once the game plays sounds in 3D.
- **Length:** a starting target, not a rule. A reload sound should match the gun's reload time, or the reload time can be changed to match the finished sound.

## In the game

| Sound | Files | Plays when |
| --- | --- | --- |
| M57 shots | `gun-m4-1` to `30` | Each shot, 100ms apart. Every sound with takes picks one at random, never the same one twice in a row. |
| B33 shots | `gun-ak47-1` to `30` | Each shot, 111ms apart |
| SMG shots | `gun-smg-1` to `29` | Each shot, 75ms apart. Take 30 exported silent. |
| Longscope shots | `gun-sniper-1` to `30`, without 12 | Each shot, 1.2s apart. Take 12 starts late and is much louder. |
| Shotgun shots | `gun-shotgun-1` to `30` | Each shot, 0.8s apart |
| Energy Pistol shots | `gun-pistol-1` to `30` | Each shot, 150ms apart |
| Assault reload | `reload-assault-v4` | B33 reload (0.985s; the file runs on with a silent tail) |
| Card skip | `card-skip` | Every right click with the cards out, which turns to the next card and cuts the flourish short if it's still playing (River's "RIGHT CLICK SKIP", 0.86s) |
| Card flourish | `card-flourish-v4` | Taking the cards out (River's "CARD ANIMATION TEST 1", 3.64s, about the flourish's 3.6s). Starts with the flourish; faded over 0.15s when the cards go away or the flourish is skipped |
| AK reload | `reload-assault-v5` | M57 reload (River's "assult reload like deadass", 1.714s file, over by about 1.5s; the reload is 2s) |
| Longscope shot base | `gun-sniper-base` | Every Longscope shot, under the take (the Longscope has no reload sound) |
| Coin burst | `coin-burst` | A kill's coins, from the body |
| Pistol snap | `pistol-snap` | The pistol hand's finger snap on a kill |
| Energy Pistol reload | `reload-pistol-v4` | Reload (0.964s) |
| Hits | `hit-body`, `hit-head`, `hit-kill` | Your shot hits a body, a head, or gets a kill |
| Low health | `hurt` | Damage leaves you at 20 health or less |
| Footsteps | `step-1` to `10` | Every 9 studs while walking or sprinting |
| Jumps | `jump-1` to `14` | A jump with Space (walking off an edge plays nothing). Each take opens with 0.1s of silence, which the game skips. |
| Menu music | `menu-music-v2.mp3` | Loops on the title screen only, and fades out over 0.6s after PLAY. |
| Outpost ambience | `outpost-ambience.ogg` | Loops while you're in the Outpost after PLAY, fading in and out over 1.5s. Game volume group. |
| Menu selection | `menu-select` | Clicking PLAY, clicks in the Outpost menu, and with each pack's opening sound. Hovering a nav row plays it quieter and higher. |
| Landings | `move-land-soft`, `move-land-hard` | Landing after at least 0.15s in the air. Hard if the fall reached 60 studs per second (a fast fall or long drop), else soft. |
| Bullet flybys | `bullet-whizz-1` to `16` | Someone else's bullet passes within 6 studs of your head and misses. Mono, played in 3D along the bullet's path (`docs/specs/guns.md`). River's takes were trimmed to 0.5s and folded to mono. |
| Slide start | `move-slide-start` | Every slide as it begins, including one started by landing |
| Pack open | `pack-open-common`, `-rarer`, `-rarest` | Once as a pack spins in, in the Menu volume group. Common for Field, rarer for Redline and Prototype, rarest for Zero-Day. |

## Still needed

In order of how much each group changes the feel. Every sound below needs a little code to hook it up once it's uploaded. The notes call out the ones that need more than that.

### 1. Core feel

| Name | When it plays | Channels | Takes | Length | Notes |
| --- | --- | --- | --- | --- | --- |
| `move-slide-loop` | Scraping for as long as a slide lasts. Must loop with no click | Mono | 1 | 1–2s | |
| `move-sprint` | Footsteps while sprinting, heavier than walking | Mono | 4 or more | 0.2s | Sprinting uses the walking steps today |
| `gun-<gun>-enemy` | Other players' shots, one per gun | Mono | 1 | Like the gun's own shot | Can be your shot summed to mono with less low end. Other players' shots are silent today, so playing them is new code. |

Other players' footsteps can't be heard either, because Roblox's default footsteps are muted and ours play only for you. That needs code, not a new sound.

### 2. Guns in full

| Name | When it plays | Channels | Takes | Length | Notes |
| --- | --- | --- | --- | --- | --- |
| `reload-smg` | SMG reload | Mono | 1 | 2.0s | |
| `reload-shotgun-shell` | Loading one shotgun shell. Plays once per shell | Mono | 1 | 0.5s or less | The game marks one reload, not each shell, so this needs a per-shell trigger |
| `gun-aim-in` | Starting to aim (Longscope only) | Mono | 1 | 0.15s | |
| `gun-aim-out` | Stopping aiming (Longscope only) | Mono | 1 | 0.15s | |
| `gun-equip-primary` | Switching to your primary | Mono | 1 | 0.3s | |
| `gun-equip-sidearm` | Switching to your sidearm | Mono | 1 | 0.2s | |
| `gun-sniper-bolt` | Working the bolt between Longscope shots | Mono | 1 | Under 1.2s | |
| `gun-shotgun-pump` | Pumping between shotgun shots | Mono | 1 | Under 0.8s | |
| `gun-dry-fire` | Pulling the trigger on an empty gun | Mono | 1 | 0.1s | An empty gun starts reloading instead today, so this rarely gets a moment |
| `bullet-impact` | A shot hits a wall or floor. Keep it neutral until arenas have real materials | Mono | 3 | 0.2s | |
| `death` | You die | Stereo | 1 | 0.8s | |

The M57's reload is keyed in `AkReload.luau` and timed to `reload-assault-v5`: the rip on its first rattle (0.36 to 0.62s), the slam on its big hit (1.08s) and the bolt flying home on its last click (about 1.47s).

### 3. Cards and movement extras

These need to be recognisable, because they tell other players what you just did.

| Name | When it plays | Channels | Length |
| --- | --- | --- | --- |
| `ability-ready` | A card comes off cooldown | Stereo | 0.3s |
| `ability-denied` | You press a card that's still on cooldown | Stereo | 0.15s |
| `dash` | Phase Dash fires | Mono | 0.4s |
| `dash-camo-end` | The near-invisibility after a dash wears off | Mono | 0.3s |
| `overclock-start` | Overclock begins | Mono | 0.5s |
| `overclock-loop` | While Overclock runs. Must loop with no click | Stereo | 1–2s |
| `overclock-end` | Overclock ends | Mono | 0.4s |
| `recon-pulse` | Recon Pulse fires | Mono | 1s |
| `recon-ping` | An enemy gets marked through a wall | Stereo | 0.3s |
| `shield-start` | Aegis Shell goes up | Mono | 0.5s |
| `shield-loop` | Hum while the shield is up. Must loop with no click | Mono | 1–2s |
| `shield-hit` | A shot lands on a shield. Should sound nothing like hitting a body | Mono | 0.2s |
| `shield-end` | The shield ends and pushes enemies away | Mono | 0.8s |
| `move-parry` | An edge parry | Mono | 0.25s |
| `move-chain-jump` | The big jump after a fast fall and slide | Mono | 0.4s |
| `wind-fall` | Air rushing during a fast fall. Must loop with no click | Stereo | 2s |
| `wind-speed` | Air rushing at high speed, faded in as you go faster. Must loop with no click | Stereo | 2s |

### 4. Outpost ambience

In the game as one loop, `outpost-ambience.ogg` (121s). Whether it loops with no click is checked in Play.

## Only if those guns come back

The SMG and Shotgun are playable. The machine pistol, revolver and auto-pistol aren't in any class, so their sounds wait until River brings them back.

| Gun | Shots | Time between shots | Reload |
| --- | --- | --- | --- |
| Machine pistol | `gun-machinepistol-1` and up | 67ms | `reload-machinepistol`, 1.6s |
| Revolver | `gun-revolver-1` and up | 400ms | `reload-revolver`, 2.2s |
| Auto-pistol | `gun-autopistol-1` and up | 109ms | `reload-autopistol`, 1.5s |

## Packs

A pack plays its rarity's opening sound as it spins in. Still without sounds: rolling, the pack tearing down its side, the cards shaking, the three cards flipping, the burst and a Zero-Day pull.

## Later, with matches

Round start, countdown, round win and loss, tower capture and match end. See `docs/specs/matches.md`.
