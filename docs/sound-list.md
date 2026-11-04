# Sound List

This list covers every sound the current game needs: 57 sounds, or 93 files once variations are counted.

Work through the stages in order. Stage 1 changes the feel the most, and I can hook each stage up as soon as you finish it.

**File names:** use the names below, adding `-1`, `-2` and so on when a sound has several takes (`gun-m4-shot-1.wav`). Matching names let me connect everything without guesswork.

**Columns:**
- **Mono:** comes from a place in the world, so the game can position it.
- **Stereo:** plays directly in your ears.
- **Length:** a starting target, not a rule. Follow your ears, except for reloads, which should match the time shown.

## Stage 1: The core feel (20 sounds, 53 files)

### Gunshots

Every gun needs 3 stereo takes of your own shot, plus 1 mono enemy version. The enemy version can be the same sound summed to mono, with less low end if that helps it sit behind your own gun.

Your own shot uses `gun-m4-shot-1.wav`. The enemy version uses `gun-m4-enemy.wav`.

Shots cut to the time between shots are fine, as long as each one ends with a tiny fade so it doesn't click. If the last shot of a burst sounds chopped, add an optional tail for that gun, such as `gun-m4-tail.wav`, and it will play when you stop firing.

| Name | Gun | Character from the game | Time between shots | Length |
| --- | --- | --- | --- | --- |
| `gun-m4` | M4 | Assault rifle, controlled, almost no recoil | 100ms | 0.3s |
| `gun-ak47` | AK-47 | Assault rifle, heavier, high recoil | 111ms | 0.35s |
| `gun-smg` | SMG | Rusher gun, light and quick | 75ms | 0.25s |
| `gun-sniper` | Sniper | One huge shot, kills on a headshot | 1.2s | 1s |
| `gun-shotgun` | Shotgun | One big close-range blast | 0.8s | 0.7s |
| `gun-pistol` | Pistol | Assault sidearm, plain and clean | 150ms | 0.3s |
| `gun-machinepistol` | Machine pistol | Rusher sidearm, tiny and very fast | 67ms | 0.2s |
| `gun-revolver` | Revolver | Marksman sidearm, slow and heavy | 400ms | 0.6s |
| `gun-autopistol` | Auto-pistol | Breacher sidearm, mid-weight automatic | 109ms | 0.25s |

### Hit feedback

These tell you what your shot did, so they need to cut through gunfire. One stereo take each.

| Name | When it plays | Length |
| --- | --- | --- |
| `hit-body` | Your shot hits someone's body | 0.1s |
| `hit-head` | Your shot hits someone's head. It should feel clearly better than `hit-body` | 0.15s |
| `hit-kill` | Your shot gets a kill | 0.4s |
| `hurt` | You take damage | 0.2s |

### Movement

| Name | When it plays | Channels | Takes | Length |
| --- | --- | --- | --- | --- |
| `move-walk` | Each footstep at walking speed | Mono | 4 | 0.2s |
| `move-sprint` | Each footstep while sprinting, heavier and faster | Mono | 4 | 0.2s |
| `move-jump` | Leaving the ground | Mono | 1 | 0.2s |
| `move-land-soft` | A normal landing | Mono | 1 | 0.2s |
| `move-land-hard` | A landing from a fast fall | Mono | 1 | 0.4s |
| `move-slide-start` | The burst at the start of a slide | Mono | 1 | 0.3s |
| `move-slide-loop` | Scraping for as long as a slide lasts. Must loop with no click | Mono | 1 | 1–2s |

## Stage 2: Guns in full (19 sounds, 22 files)

### Reloads

One mono file per gun. Each one should last the reload time shown, so the sound lines up with the action.

| Name | Gun | Length |
| --- | --- | --- |
| `reload-m4` | M4 | 2.2s |
| `reload-ak47` | AK-47 | 2.4s |
| `reload-smg` | SMG | 2.0s |
| `reload-sniper` | Sniper | 3.0s |
| `reload-shotgun-shell` | Shotgun, one shell. It plays once per shell | 0.5s or less |
| `reload-pistol` | Pistol | 1.4s |
| `reload-machinepistol` | Machine pistol | 1.6s |
| `reload-revolver` | Revolver | 2.2s |
| `reload-autopistol` | Auto-pistol | 1.5s |

### Handling

One mono take each.

| Name | When it plays | Length |
| --- | --- | --- |
| `gun-dry-fire` | Pulling the trigger on an empty gun | 0.1s |
| `gun-equip-primary` | Switching to your primary | 0.3s |
| `gun-equip-sidearm` | Switching to your sidearm | 0.2s |
| `gun-aim-in` | Starting to aim down sights | 0.15s |
| `gun-aim-out` | Stopping aiming | 0.15s |
| `gun-sniper-bolt` | Working the bolt between sniper shots | Under 1.2s |
| `gun-shotgun-pump` | Pumping between shotgun shots | Under 0.8s |

### Bullets and death

| Name | When it plays | Channels | Takes | Length |
| --- | --- | --- | --- | --- |
| `bullet-impact` | A shot hits a wall or floor. Keep it neutral until arenas have real materials | Mono | 3 | 0.2s |
| `bullet-whizz` | A shot flies past your head | Mono | 2 | 0.2s |
| `death` | You die | Stereo | 1 | 0.8s |

## Stage 3: Abilities and movement extras (18 sounds, 18 files)

### Abilities

These need to be recognisable, because they tell other players what you just did. One take each.

| Name | When it plays | Channels | Length |
| --- | --- | --- | --- |
| `ability-ready` | A card comes off cooldown | Stereo | 0.3s |
| `ability-denied` | You press a card that's still on cooldown | Stereo | 0.15s |
| `dash` | Phase Dash fires | Mono | 0.4s |
| `dash-camo-end` | The near-invisibility after a dash wears off | Mono | 0.3s |
| `overclock-start` | Overclock begins | Mono | 0.5s |
| `overclock-loop` | Plays while Overclock runs. Must loop with no click | Stereo | 1–2s |
| `overclock-end` | Overclock ends | Mono | 0.4s |
| `recon-pulse` | Recon Pulse fires | Mono | 1s |
| `recon-ping` | An enemy gets marked through a wall | Stereo | 0.3s |
| `shield-start` | Aegis Shell goes up | Mono | 0.5s |
| `shield-loop` | Hum while the shield is up. Must loop with no click | Mono | 1–2s |
| `shield-hit` | A shot lands on a shield. It should sound nothing like hitting a body | Mono | 0.2s |
| `shield-end` | The shield ends and pushes enemies away | Mono | 0.8s |

### Movement extras

One take each.

| Name | When it plays | Channels | Length |
| --- | --- | --- | --- |
| `move-parry` | An edge parry | Mono | 0.25s |
| `move-climb` | Climbing up a ledge | Mono | 0.35s |
| `move-chain-jump` | The big jump after a fast fall and slide | Mono | 0.4s |
| `wind-fall` | Air rushing during a fast fall. Must loop with no click | Stereo | 2s |
| `wind-speed` | Air rushing at high speed. I'll fade it in as you go faster. Must loop with no click | Stereo | 2s |

## Upload limit

Unverified accounts can upload 100 sounds every 30 days, and this list uses 93. Replacing sounds counts too, so you'd hit the limit quickly while tweaking them. ID verification raises it to 2,000.

## Not needed yet

Match sounds wait for Phase 4: round start, countdown, round win and loss, tower capture and match end.
