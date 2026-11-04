# Movement and Combat Design

This sub-project delivers a fully playable match on PC: first-person movement, 5 guns across 4 classes, the 5 ability cards, and two round-based modes in blockout arenas. All numbers are starting values to tune by feel unless marked as decided.

**Parent spec:** https://claude.ai/artifact/P6cgJtFzpNRJJcx53PMoMH. Where the two differ, this document wins for combat.

## Goals

- Fast, fluid first-person fights where a skilled player with a Field deck can beat a weaker player with a Prototype deck.
- Short rounds that feel tense, with fast matches overall.
- Rules live in pure tested modules, so tuning and later input methods need no rewrites.

**Success means:** a full match of each launch queue runs start to finish in Studio with no errors, cheat checks catch a simulated speed hack, and River signs off on how movement, recoil and time to kill feel.

**Out of scope:** matchmaking, the hub, rewards, final art and sound, gun upgrades, mobile and console controls. Mobile and console come after PC, so input stays separate from game logic.

## Launch queues

| Mode | Team sizes |
| --- | --- |
| Elimination | 1v1, 2v2, 3v3 |
| Tower | 5v5 |

The code takes mode and team size as settings, so the other 4 combinations can open later without changes to the rules.

## Rounds in both modes

- Each round starts with full health, full ammo and every card ready.
- Health is 100 and does not regenerate during a round.
- There are 8 seconds between rounds to change class or Assault rifle.
- Dead players spectate living teammates until the round ends.
- A disconnected player counts as dead for that round and stays out of later rounds. A team with nobody left forfeits the match.

## Elimination mode

- One arena per match. The first team to 5 round wins takes the match, so a match has at most 9 scored rounds.
- A round is won by eliminating the other team. There is no objective.
- A round has a 90-second limit. At the limit, the team with more players alive wins, then the team with more total health. An exact tie replays the round and scores nothing.

## Tower mode

The mode uses original arena names and layouts.

- **Arenas:** 7 in a line. Matches start in arena 4, and each side's end arena is its home arena.
- **Tower:** each arena has one tower. A living player within 6 studs presses E to capture it instantly. Towers can be retaken any number of times.
- **Attackers and defenders:** every round has one attacking team and one defending team. Defenders own the tower when the round starts.
- **Who attacks:** the first round's roles are random. After that, the team that won the last round attacks. The tiebreaker arena's roles are random.
- **Round length:** 40 seconds, or 60 seconds in a home arena.
- **Winning a round:** the team that owns the tower when time expires wins. Attackers must capture it and keep it; defenders win by holding it.
- **Elimination:** the round ends at once if the team that owns the tower wipes the other team. Otherwise, the wiping team has up to 14 seconds to capture the tower. If they fail, they lose the round.
- **Progress:** a round win moves the next round one arena toward the loser's home arena.
- **Match win:** capturing the tower in the enemy's home arena wins the match immediately. A clean sweep takes 4 straight round wins.
- **Limits:** 15 rounds at most. At 7-7, one deciding round is played in a dedicated tiebreaker arena, and it decides the match. If the limit is reached any other way, the team with more round wins takes the match.

## Movement

The player's client moves their character using a Humanoid-based controller. Roblox Server Authority was considered and declined.

| Move | Speed (studs/sec) | Rule |
| --- | --- | --- |
| Walk | 16 | Default speed |
| Sprint | 24 | Any direction, no stamina, small accuracy penalty |
| Slide | Starts at 42, slows over 0.9s | Starts from a sprint, any direction, no cooldown |
| Slide-cancel | Crouch keeps current speed; jump adds 8 | Jump or crouch to end a slide early. A jump holds its speed in the air and fades over 0.6s after landing |
| Jump | 6 studs high | Small accuracy penalty in the air |

Players can aim and shoot in any direction during every move. The camera is first-person. Other players see the full character sliding and turning.

## Cheat checks

- The server compares each player's movement against the fastest legal speed for their current state, with a lag allowance, slides and Phase Dash included.
- A failed check moves the player back to their last valid position and adds a strike. Too many strikes in one match removes the player from the match and logs it. There are no automatic bans.
- The server rejects shots from impossible positions.
- The server alone controls health, ammo, ability use and tower capture.

## Classes and guns

Classes are free, change guns only, and work with any cards. Each class has 1 primary and 1 sidearm. Assault is the one exception: it chooses the M4 or AK-47. Players can change class or rifle between rounds.

**Primaries**

| Class | Gun | Body damage | Headshot | RPM | Mag | Reload | Recoil | Range |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Assault | M4 | 24 | 2x (48) | 600 | 30 | 2.2s | Almost none | 100% to 90 studs, 70% by 180 |
| Assault | AK-47 | 24 | Instant kill | 540 | 30 | 2.4s | High | 100% to 90 studs, 70% by 180 |
| Rusher | SMG | 17 | 2x (34) | 800 | 32 | 2.0s | Low | 100% to 40 studs, 60% by 90 |
| Marksman | Sniper | 85 | Instant kill | 50 | 5 | 3.0s | One large kick | No falloff; poor accuracy without aiming down sights |
| Breacher | Shotgun | 8 pellets of 14 (112) | 2x per pellet | 75 | 6 | 0.5s per shell | One large kick | 100% to 15 studs, 0% by 45 |

**Sidearms** (headshots do 2x on all of them)

| Class | Gun | Body damage | RPM | Mag | Reload |
| --- | --- | --- | --- | --- | --- |
| Assault | Pistol | 20 | 400 | 12 | 1.4s |
| Rusher | Machine pistol | 13 | 900 | 20 | 1.6s |
| Marksman | Revolver | 45 | 150 | 6 | 2.2s |
| Breacher | Auto-pistol | 16 | 550 | 15 | 1.5s |

**Decided by River:** the M4 has almost no recoil and does 2x headshot damage. The AK-47 has high recoil and kills on any headshot. The sniper kills on any headshot. This replaces the parent spec's general headshot multiplier.

Guns add 0 to Deck Power Rating, because gun upgrades wait until after launch.

## Hit checking

Shots are instant. The client reports each shot with its aim and firing time, and the server checks it against stored target positions.

- The server keeps 1 second of position history for each player.
- It rewinds targets to the firing time, capped at 200ms, then runs its own raycast.
- The server then decides damage. The client never reports damage or health.

## Ability cards

Each match reads deck and stats from Card core. Cards work in both modes and reset at the start of each round.

| Card | Cooldown (Field / Black-Site / Prototype) | Behavior |
| --- | --- | --- |
| Phase Dash | 12s / 11s / 10s | Instant burst in the move direction |
| Overclock | 25s | Fire-rate bonus for the equipped gun |
| Recon Pulse | 20s | Reveals enemies in a radius through walls |
| Aegis Shell | 25s | Shield that takes body damage first |
| Arc Mine | 30s | Placed mine with a 6-stud trigger, armed after 1 second, one active per player |

- An instant-kill headshot breaks an active Aegis Shell and leaves the player alive. Other damage beyond the shield's remaining HP is lost.
- The HUD shows cooldowns as segmented bars.

**Card data changes in Card core**

| Card | Change |
| --- | --- |
| Aegis Shell | Prototype duration 3.75s (was 4s) |
| Arc Mine | Prototype slow 1.875s (was 2s) |
| Arc Mine | Prototype perk is now "hidden from enemies until triggered" (`hidden_until_triggered`), replacing 2 charges |

Those changes remove both ceiling exemptions, so every stat is back inside the 20–25% limit.

## Arenas

- Grey blockouts only. Real art comes in the UI and art sub-project.
- Tower: 7 arenas sized for 5v5, plus 1 tiebreaker arena.
- Elimination: a smaller arena reused for all 3 team sizes, walled in for 1v1.

## Architecture

| Layer | Holds | Tested by |
| --- | --- | --- |
| Pure rules in `src/shared/` | Gun stats, damage and falloff, headshot rules, cooldowns, movement limits, round scoring, tug-of-war position | Lune tests |
| Server in `src/server/` | Health, shot checks, position history, abilities, strikes, towers, match flow | Studio playtests |
| Client in `src/client/` | Camera, movement, shooting, recoil, HUD | Studio playtests and River |

- Save data moves to version 2 and adds the player's class and Assault rifle. Version 1 saves migrate to Assault with the M4.
- Clients send input and aim only. Remote payloads go through the same parsing approach as `Requests.luau`.
- Input is read through one module, so touch and controller can be added later.

## Testing

- Rule modules are built test-first, as in Card core.
- Claude runs Studio playtests through Studio MCP, reads errors, and simulates speed hacks and bad shots.
- River judges how movement, recoil and time to kill feel.

## Build phases

Each phase gets its own plan and ends in something testable.

1. **Movement:** controller, camera and cheat checks in a test room.
2. **Guns:** classes, shooting, hit checking, health and ammo.
3. **Abilities:** the 5 cards, HUD cooldown bars and the Card core data changes.
4. **Matches:** round flow, both modes, blockout arenas and a basic score display.

## Risks

| Risk | Mitigation |
| --- | --- |
| Client-owned movement lets some cheats through | Server limits, strikes and server-owned outcomes |
| Instant-kill guns dominate | AK-47 recoil and sniper fire rate are tuned first; both are data values |
| Headshots are hard on touchscreens later | Aim assist is designed with mobile controls |
| 40-second rounds feel short at 5v5 | Round length is a config value |
| Testing real fights needs several players | Studio's multi-client test mode, if available through tools; otherwise River helps test |

## Changes to the parent spec

- Headshots follow the gun table, not one multiplier.
- Adds classes and the Assault rifle choice.
- Adds the Elimination and Tower modes and the launch queues.
- Applies the card data changes above.
- Gun upgrades wait until after launch.
