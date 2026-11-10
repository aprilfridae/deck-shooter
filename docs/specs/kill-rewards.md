# Kill rewards and pop-ups

**Status:** built on 2026-11-10, waiting on River's check in Play. The rules and the timing are tested; the look, and real Credits landing between two players, are not.

**Values live in:** `src/shared/Guns/KillRewards.luau` for the amounts and rules, `src/shared/Guns/Hud/KillPopupTiming.luau` for the pop-ups' timings, and the constants at the top of `src/client/KillPopups.luau` for where they sit and their type.

## Goal

A kill should feel good the way it does in Call of Duty: lines pop up beside the crosshair naming what you did, each with an amount, and a total counts up. The amounts are real. They are added to the player's saved Credits, the same Credits cards earn and rebirths cost.

## What pays

| Line | When | Credits |
|---|---|---|
| `KILL` | Every kill of a paying target | 500 |
| `HEADSHOT` | The killing bullet hit the head | 100 |
| `ONE SHOT ONE KILL` | The target was at full health and one bullet killed it | 100 |
| `LONG SHOT` | The kill was from 150 studs or more | 150 |
| `COLLATERAL` | One bullet killed two or more targets. Once for the shot, not once for each body | 250 |
| `KILLING SPREE` | The kill is the player's 3rd without dying | 200 |
| `RAMPAGE` | The 5th without dying | 400 |
| `UNSTOPPABLE` | The 10th without dying | 1,000 |

- Every line that applies to a kill is shown and paid. A Longscope bullet through two full-health players at 160 studs pays `KILL` twice, `ONE SHOT ONE KILL` twice, `LONG SHOT` twice and `COLLATERAL` once: 1,750.
- A streak line fires once, on the kill that reaches its count. The count goes back to 0 when the player dies or leaves. Kills that don't pay don't count toward it.
- "One bullet" means one bullet. A shotgun blast that kills with several pellets isn't a one shot one kill.
- Distance is measured from where the shooter stood to where the target stood when the bullet was fired.
- The names and amounts are starting numbers to tune. At 500 a kill, 50 kills is the first rebirth (25,000).

## Who pays

- A target pays if it's a player's character, or its model has the attribute `PaysKill = true`.
- The test dummy doesn't have it and never pays.
- River plans bots that pass for players once there are maps. They get the flag and pay exactly as players do. Nothing else needs to change for them.
- A kill of a target that doesn't pay still shows its lines, with no amounts and no total, so the pop-ups can be seen and tuned alone in the test room.

## Stopping kill trading

The same victim pays the same killer only once every 20 seconds. A second kill inside that time shows its lines with no amounts, adds nothing, and doesn't count toward a streak. Ordinary fights don't reach it; two players trading kills in a corner earn a small share of what they would.

## How it works

- The server decides everything. In `GunServer.server.luau`, where a shot's damage is applied, it already knows who fired, which targets died, whether the bullet was a collateral and whether it hit the head. It also notes each target's health before the shot, how many bullets hit it, and the distance.
- `KillRewards.luau` is pure rules with no Roblox in it: given what happened in one shot and the killer's record (streak count and when each victim last paid), it returns the lines to show, the Credits to add and the new record. That makes it testable.
- The server adds the Credits to the killer's saved data through `PlayerCards`, capped at `Config.MaxCredits`, and marks it changed so it is saved and the lobby's Credits line updates the same way income does.
- The server sends the killer one `KillReward` message for the shot: the lines in order and the total. Nothing about amounts is ever taken from a client.
- A player's record lives on the server for as long as they're in the game. It isn't saved.

## The pop-ups

- Only the player who made the kill sees them.
- They stack just right of the crosshair, newest on top, older lines sliding down. Up to 5 show; the oldest drops off.
- Each line is its name on the left and its amount on the right, like `ONE SHOT ONE KILL   +100`.
- A line punches in at 1.25 times its size and settles in 0.12s, holds for 2s, and fades over 0.3s.
- Above the stack one total, like `+850 CR` (plain digits: the HUD's type has no comma), counts up to its new value over 0.35s each time lines arrive, and clears after 2.5s with nothing new.
- They use the HUD's own type (`TypeLabel`): names in Bone, amounts and the total in Signal Acid, which is the colour of the coins that fly into the killer.
- They hide with the rest of the HUD (the title screen, the Outpost). They stay up while scoped, so a Longscope kill shows them. One shot's lines land 0.07s apart, the kill first.
- No sound yet. Each line kind has a slot for one, so River can add them later.

## Checks

- Lune: `killrewards_spec` covers each line's rule, that lines stack, the amounts, streak counts and their reset, that a target without the flag shows lines and pays nothing, and the 20 second rule; and the pop-ups' pure timing: a line's size and fade at each moment, and the total's count-up and clearing.
- River in Play: the look and feel, on the dummy. Real Credits landing needs Studio's two-player test, because only players pay.

## Not in this

More medals, a kill feed other players see, sounds, and the bots themselves.
