# Matches

**Status:** Elimination is built (2026-11-18): the 1v1, 2v2 and 3v3 queues, rounds, scoring, spectating, the between-round class pick, the score display and the cheat-check change. It has been played alone in Studio against stand-ins, not yet by two or more people, and River hasn't judged its feel. Tower is not built. Matches were parked until gameplay felt good; River un-parked them by asking for "stuff from the overarching plan".

## How Elimination is built

- **Rules:** `src/shared/Guns/MatchRules.luau` (round result, forfeit, match winner, team split), tested in `tests/matchrules_spec.luau`. The HUD's words are in `src/shared/Guns/Hud/MatchText.luau`.
- **Server:** `src/server/Matches.server.luau` runs the queues and every match. Up to 6 matches run at once; a full queue waits for a free arena.
- **Arenas:** each match builds its own copy of its arena far out from the free-play maps (from x = 9000, 1600 studs apart) and removes it at the end. 1v1 plays a copy of Hex or Relay, picked at random, with its OUTPOST terminals turned off. 2v2 and 3v3 play the **Yard** (`src/server/Outpost/Yard.luau`): a walled 140 by 90 grey blockout with an unseen fence above the walls, a spawn bay behind a wall with two exits on each side, low cover and pillars down both flanks, and a raised middle with a ramp from each side. Side 1's accents are teal and side 2's orange; its lights are white. Players keep the map's zone (Hex, Relay or the new Yard zone), so its lighting and fall check work as in free play.
- **Teams:** two Roblox Teams per match (teal and orange). Bullets pass through teammates, cards already treat a teammate as a friend, and teammates get an outline in the team colour.
- **A round:** everyone still in the match gets a fresh body at their side's spawn (full health, ammo and cards), held in place for a 3-second countdown with guns and cards off (the `MatchFrozen` attribute). The round ends on a wipe or at 90 seconds. The dead stay dead (no 3-second respawn) and, after 2.5 seconds of the death view, watch a living teammate over the shoulder; a click moves to the next one.
- **Between rounds:** 8 seconds, held at the spawn, with buttons for each class. The pick applies on the next round's body.
- **The end:** VICTORY or DEFEAT for 6 seconds, then everyone goes back to the Outpost and the arena, teams and state are removed.
- **Leaving:** a player who leaves the game counts as dead and stays out; a team with nobody left forfeits. Five movement strikes in a match remove the player from it, log it and send them to the Outpost instead of kicking them; strikes start over in each match.
- **The Play page:** each Elimination row says JOIN, how many are waiting, or IN QUEUE n/size. Click to join, click again to leave. Leaving the Outpost leaves the queue. In Studio a right-click starts a match at once against stand-in bodies that never shoot, to test alone.
- **What a client reads:** `ReplicatedStorage.Matches.<id>` attributes (Phase: Countdown, Playing, Between or Over; PhaseEnds; Round; Wins1; Wins2; RoundWinner, 0 for a replayed tie; Winner, 0 when nobody was left; Arena; TeamSize; RoundSeconds), the player's `MatchId` and `MatchTeam`, and queue counts on `ReplicatedStorage.MatchQueues`.
- **Reward:** each winner still in the match gets 1 Catalyst when the match is won on rounds; a forfeit or a Studio test against stand-ins pays nothing (`cards.md`). Kills in a match pay Credits as anywhere else.
- **Not built:** cross-server matchmaking (a queue only matches players on the same server), a match sound set.

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

**Built so far (2026-11-18):** only the rules, in `src/shared/Guns/TowerRules.luau` with tests in `tests/towerrules_spec.luau`: the arena line and push, roles, round lengths, capture range, the round result with the 14-second capture window, the sweep, the 15-round limit and the 7-7 tiebreaker. No arenas, server, queue or HUD yet. Three things the design below leaves open were chosen there, as starting values: when both teams are wiped together the tower's owner wins; the 14-second capture window runs on past the round clock; the tiebreaker round lasts 60 seconds.

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
- The first 1v1 map, Relay, is built as a free-play zone (`relay.md`). It's not a grey blockout: River asked for the real look straight away.

## What matches change in built systems

- **Cards** reset at the start of each round: every round gives a fresh body, and cards reset on each spawn. The Studio test decks (T and Y) still work in matches, in Studio only.
- **Loadout:** the 8-second between-round screen picks the class.
- **Death:** spectating replaces the 3-second respawn (`Places.holdRespawn`).
- **Cheat checks:** 5 strikes remove the player from the match and log it, instead of kicking them from the server. Strikes count per match. Built.
- **Teams:** assigned per match. The "everyone else is an enemy" rule in `AbilityServer` already follows Team; guns now skip teammates.
- **Server authority:** the server alone controls tower capture, as it already does health, ammo and ability use.
- **HUD:** a score display at the top centre (`MatchHud.client.luau`).
- **Queues:** the Play page's Elimination rows join queues; Tower still says `SOON`. The Outpost's matchmaking booth is scenery with no prompt (`outpost.md` says it has one; it isn't in the code).

## Risks

| Risk | Mitigation |
| --- | --- |
| Instant-kill guns dominate | B33 recoil and Longscope fire rate are tuned first; both are data values |
| Headshots are hard on touchscreens later | Aim assist is designed with mobile controls |
| 40-second rounds feel short at 5v5 | Round length is a config value |
| Testing real fights needs several players | Studio's multi-client test, run by River |

## Out of scope

Matchmaking, rewards, gun upgrades, and mobile and console controls. Mobile and console come after PC, which is why input stays separate from game logic.
