# Guns

**Status:** built for the test room. Checked against the code on 2026-11-07.

**Values live in:** `src/shared/Guns/GunConfig.luau` for gun stats and classes. Ammo and reload rules are in `Weapon.luau`, damage in `Damage.luau`, spread in `Spread.luau` and recoil in `src/client/Recoil.luau`. Hit checking uses `ShotRequest.luau` (rewind and origin limits), `Hitbox.luau` (hitbox sizes: one for the soldier, one for plain Roblox bodies such as the test dummy) and `History.luau` (position history), and `src/server/GunServer.server.luau` holds the respawn time, range and request limit.

## Classes

Classes are free, change guns only, and work with any cards. Each class has 1 primary and 1 sidearm. For now players can only pick Assault with the M57, or Marksman. The B33, Rusher and Breacher stay in the gun data, and a save holding one of them falls back to the default.

| Class | Primary | Sidearm |
| --- | --- | --- |
| Assault | M57 or B33 | Energy Pistol |
| Rusher | SMG | Energy Pistol |
| Marksman | Longscope | Energy Pistol |
| Breacher | Shotgun | Energy Pistol |

New players start as Assault with the M57. The class and Assault rifle are saved.

The code and saves use internal ids, and players see display names: `M4` is the M57, `AK47` the B33, `Sniper` the Longscope, `Pistol` the Energy Pistol.

## Decided by River

- All guns are hip fire only, except the Longscope, which can aim down sights. The base and firing gun pose always points straight.
- The M57 has almost no recoil and does 2x headshot damage. The B33 has high recoil and kills on any headshot. The Longscope kills on any headshot. These replace the parent spec's single headshot multiplier.
- Every class uses the Energy Pistol as its sidearm for now. The machine pistol, revolver and auto-pistol stay in the gun data, unused, until River brings them back.
- Guns add 0 to Deck Power Rating. Gun upgrades wait until after launch.

## Gun stats

Damage falls off in a straight line between the two distances, then stays flat. Spread is the cone the server rolls each shot in, in degrees.

| Gun | Body damage | Headshot | RPM | Mag | Reload | Fire | Spread | Range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| M57 | 24 | 2x | 600 | 30 | 0.985s | Auto | 0.2 | 100% to 90 studs, 70% by 180 |
| B33 | 24 | Kill | 540 | 30 | 0.985s | Auto | 0.4 | 100% to 90 studs, 70% by 180 |
| SMG | 17 | 2x | 800 | 32 | 2.0s | Auto | 0.8 | 100% to 40 studs, 60% by 90 |
| Longscope | 85 | Kill | 50 | 5 | 1.714s | Single | 0 aimed, 7 from the hip | No falloff |
| Shotgun | 8 pellets of 14 | 2x per pellet | 75 | 6 | 0.5s per shell | Single | 4 per pellet | 100% to 15 studs, 0% by 45 |
| Energy Pistol | 20 | 2x | 400 | 12 | 0.964s | Single | 0.4 | 100% to 40 studs, 70% by 90 |

**In the data, unused:** Machine pistol (13 damage, 900 RPM, 20 rounds, 1.6s, auto, spread 1), Revolver (45, 150, 6, 2.2s, single, 0.3) and Auto-pistol (16, 550, 15, 1.5s, single, 0.6). All three do 2x on headshots and use the Energy Pistol's falloff.

- A 2x headshot applies after falloff, so the M57 does 48 to the head only within 90 studs.
- The M57, B33, Longscope and Energy Pistol reload times match their reload sounds (`GunSounds.luau`). The SMG and Shotgun have no reload sound yet.

## Recoil

- Each gun has a fixed spray pattern, so sprays can be learned. A pattern is a list of points (shots fired, degrees up, degrees sideways) joined by straight lines. Automatics climb nearly straight for a third of the magazine, then sweep side to side.
- Bullets land on the pattern. The camera follows 45% of the way.
- 0.12s after the last shot, the spray recovers at the gun's `recovery` rate (shots forgiven per second) and the camera drifts straight back.
- The client applies recoil, so a no-recoil cheat is an accepted risk. The server rolls spread, so a client can't remove it.

## Keys

These are the defaults. Players can rebind all but the test keys in Settings (`outpost-ui.md`).

| Key | Action |
| --- | --- |
| Left mouse | Fire. Also uses a held card. |
| Right mouse | Aim down sights (Longscope only) |
| R | Reload |
| 1, 2 | Primary, sidearm |
| B, N | Next class, next Assault rifle. Test keys, until matches add a between-round screen. |

A class or rifle change applies at once if the player is at full health and both magazines are full with no reload running. Otherwise it applies at the next respawn.

## Ammo and reloads

- Each gun keeps its own magazine across swaps. Spare ammo is unlimited. A respawn gives full ammo.
- R does nothing if the magazine is full or a reload is running. Firing an empty gun starts a reload.
- A magazine gun can't fire while reloading and refills completely at the end.
- The Shotgun loads one shell every 0.5s. Firing it stops the reload.
- Swapping guns cancels the reload of the gun being put away.
- Single-fire guns fire once per click.
- Overclock shortens the time between shots on both guns (see `cards.md`).
- The client counts its own ammo down while firing. It takes the server's `Ammo` attribute whenever that changes, and again once 0.3s have passed since the last shot. The HUD shows RELOADING while a reload runs.

## Hit checking

Shots are instant. The server alone decides damage, health and ammo (`src/server/GunServer.server.luau`).

- The client sends each shot's origin, direction (with recoil applied), firing time and whether it was aiming.
- The firing time is clamped to between 0.2s ago and now.
- The origin must be within 6 studs of where the server had the shooter at the firing time plus ping (or now), with no wall between their body and the origin.
- The fire rate is checked against the firing time, with 5% tolerance for network timing.
- The server records every target's position and pose 20 times a second and keeps 1s of history. Targets are rewound to the firing time minus ping minus 0.08s, but never more than 0.2s back.
- The server's raycast hits walls only. It casts with the `Shots` collision group, so invisible feet-only walls (the `WalkOnly` group, such as the Relay map's railings) don't stop bullets (`Collision.luau`). Targets are tested against shapes at their rewound positions: a head sphere (radius 0.8) and a body cylinder (radius 1.1). On a soldier body the head is 2.9 studs above the root part and the body runs from 3.3 below the root to 2.1 above. On a plain Roblox body, such as the grey test dummy, the head is 2 above and the body runs from 3 below to 1.2 above (`Hitbox.shapes`). Crouching lowers the head and the top of the body 1.5 studs, and sliding 2.5. The bottom of the body doesn't move.
- Range is 1000 studs. Pellet damage is added up per target before it's applied.
- Reload, swap and loadout requests are limited to 10 per second in total.

## Health and respawn

- Health is 100 and doesn't regenerate. `src/character/Health.server.luau` is an empty script that replaces Roblox's regeneration script.
- The server owns health (`GunTargets.luau`). An Aegis Shell takes every hit while it's up (see `cards.md`).
- Players respawn after 3s.
- In the Outpost, the server refuses shots and reloads (see `outpost.md`).

## View models and effects

- Gun models come from `ReplicatedStorage.GunModels` in the group's place, found by display name. A gun with no model shows a grey block. A local export in `assets/models/GunModels.rbxm` had the M57, B33, SMG, Longscope, Energy Pistol, `Arms` and `Card`, with no Shotgun model. That hasn't been checked against the group's place.
- First person shows the soldier's arms (`GunModels.SoldierArms`), not the old `Arms` model. `src/shared/Guns/SoldierPose.luau` lines the soldier's hands up with the arm clips' palms and bends the arms to reach from shoulders kept out of view (`SHOULDERS`, the tuning point if the arms look wrong), so clip timing is unchanged. Guns without a clip (B33, SMG, Longscope, Shotgun) use their grips and the M57's idle fingers. Only the first-person arms jitter.
- Arm animations exported from Blender exist for the M57, the Energy Pistol and the card (`src/shared/Guns/ArmClips/`). The M57 and Energy Pistol each have 3 reload takes (`reload`, `reload2`, `reload3`) that differ only in position, and one is picked at random. Other guns use arms posed in code. `docs/HANDOFF.md` has the export steps.
- The test room has two targets with real health that respawn after 3s (`src/server/TargetDummy.server.luau`): a plain grey Roblox body and a soldier copied from the first player to spawn as one, which holds the M57 in its standing pose.
- Tracers, impacts and bullet holes: `ShotEffects.client.luau` and `BulletHoles.client.luau`.
- Sounds: `GunAudio.luau`, with ids in `GunSounds.luau` and `SoundIds.luau`.
- Flybys: when someone else's bullet passes within 6 studs of your head without hitting you (`Flyby.RADIUS`), a `bullet-whizz` take plays, once per shot, from the closest pellet. It's a 3D sound that starts on the bullet's path and travels along it past your head at 60 studs a second, so it comes from the side the bullet passed and moves the way it went. It's timed so the whizz peaks as the tracer reaches you. `Flyby.luau` and `ShotEffects.client.luau`.
