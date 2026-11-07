# Matches

**Status:** planned, not built. There is no round, match, team, tower or arena code yet. River has parked matches (Phase 4) until gameplay looks, sounds and feels good. The 1v1 map is the next step toward them.

This is the design agreed for matches. All numbers are starting values to tune by feel unless marked as decided.

## Goals

- Fast, fluid first-person fights where a skilled player with a Field deck can beat a weaker player with a Prototype deck.
- Short rounds that feel tense, and fast matches overall.
- Rules live in pure, tested modules in `src/shared/`, such as round scoring and the Tower mode's arena position.

**Done means:** a full match of each launch queue runs start to finish with no errors, the cheat checks catch a simulated speed hack, and River signs off on the feel in Play.

## Launch queues

| Mode | Team sizes |
| --- | --- |
| Elimination | 1v1, 2v2, 3v3 |
| Tower | 5v5 |

Mode and team size are settings, so the other 4 combinations can open later without changing the rules.

## Rounds in both modes

- Each round starts with full health, full ammo and every card ready.
- Health is 100 and doesn't regenerate during a round.
- There are 8 seconds between rounds to change class or Assault rifle.
- Dead players spectate living teammates until the round ends.
- A disconnected player counts as dead for that round and stays out of later rounds. A team with nobody left forfeits the match.

## Elimination

- One arena per match. The first team to 5 round wins takes the match, so a match has at most 9 scored rounds.
- A round is won by eliminating the other team. There is no objective.
- A round lasts at most 90 seconds. At the limit, the team with more players alive wins, then the team with more total health. An exact tie replays the round and scores nothing.

## Tower

The mode uses original arena names and layouts.

- **Arenas:** 7 in a line. Matches start in arena 4, and each side's end arena is its home arena.
- **Tower:** each arena has one. A living player within 6 studs presses E to capture it instantly. Towers can be retaken any number of times.
- **Attackers and defenders:** every round has one attacking and one defending team. Defenders own the tower when the round starts.
- **Who attacks:** the first round's roles are random. After that, the team that won the last round attacks. The tiebreaker arena's roles are random.
- **Round length:** 40 seconds, or 60 in a home arena.
- **Winning a round:** the team that owns the tower when time runs out wins. Attackers must capture it and keep it; defenders win by holding it.
- **Elimination:** the round ends at once if the team that owns the tower wipes the other team. Otherwise the wiping team has up to 14 seconds to capture the tower, or it loses the round.
- **Progress:** a round win moves the next round one arena toward the loser's home arena.
- **Match win:** capturing the tower in the enemy's home arena wins the match at once. A clean sweep takes 4 straight round wins.
- **Limits:** 15 rounds at most. At 7-7, one deciding round is played in a dedicated tiebreaker arena. If the limit is reached any other way, the team with more round wins takes the match.

## Arenas

- Grey blockouts first. Real art comes later.
- Tower: 7 arenas sized for 5v5, plus 1 tiebreaker arena.
- Elimination: a smaller arena reused for all 3 team sizes, walled in for 1v1.

## What matches change in built systems

- **Cards** reset at the start of each round instead of on each spawn (`AbilityServer.server.luau`). The Studio test decks (T and Y) go.
- **Loadout:** the B and N test keys are replaced by the 8-second between-round screen.
- **Death:** spectating replaces the 3-second respawn.
- **Cheat checks:** 5 strikes remove the player from the match and log it, instead of kicking them from the server. Strikes count per match.
- **Teams:** teams get assigned. Recon Pulse's teammate perk and the "everyone else is an enemy" rule in `AbilityServer` depend on it.
- **Server authority:** the server alone controls tower capture, as it already does health, ammo and ability use.
- **HUD:** a basic score display.
- **Queues:** the Play page's queue rows (`PlayPanel.luau`) and the matchmaking booth's prompt in the Outpost say `SOON` and do nothing until matches exist.

## Risks

| Risk | Mitigation |
| --- | --- |
| Instant-kill guns dominate | B33 recoil and Longscope fire rate are tuned first; both are data values |
| Headshots are hard on touchscreens later | Aim assist is designed with mobile controls |
| 40-second rounds feel short at 5v5 | Round length is a config value |
| Testing real fights needs several players | Studio's multi-client test, run by River |

## Out of scope

Matchmaking, rewards, gun upgrades, and mobile and console controls. Mobile and console come after PC, which is why input stays separate from game logic.
