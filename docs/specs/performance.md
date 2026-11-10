# Performance

**Status:** first pass on 2026-11-10, done by reading the code. None of it has been measured on a slow machine or seen in Play. Phones are a separate job.

**Values live in:** `src/shared/Guns/PerfLevel.luau` for when the quality level steps, and at each place that uses `Perf.pick` for what it changes.

## Where the cost was

The world is light: shadows are off, and the maps are small and built at run time. Nearly all the cost is the first-person view and the effects on top of it:

- **Motion blur.** Every blur copy is a whole extra gun, pair of arms or card. At their fullest that was 12 copies of the gun (25 to 35 thousand triangles each) each with a pair of arms (84 parts, posed again in code), 8 pairs of arms with the cards out, and 192 blur cards.
- **Kill coins.** 30 physics parts, each drawing about 50 lines three times.
- **Hit effects.** An automatic made and destroyed hundreds of parts a second.
- **Gun models.** They're drawn in first person, again for each blur copy, and again in every other player's hands.

## Quality levels

`Perf.luau` gives the client a level from 3 (everything) to 1 (the least), and anything that draws extras asks `Perf.pick(high, medium, low)`.

- It follows the frame rate (`PerfLevel.luau`, tested): under 45 frames a second for 1.5s steps it down; over 57 for 8s steps it back up. A frame of a quarter of a second or more is a hitch and isn't counted.
- If stepping up is followed by stepping down within 15s, that higher level is too much for the machine and isn't tried again for 3 minutes, so it doesn't flicker between two levels.
- A player who has set Roblox's own graphics quality to 3 or less starts at level 1, and at 6 or less at level 2.
- The level is on the player as the attribute `PerfLevel`, to check while testing.
- It only ever changes decoration. Nothing about how the game plays depends on it.

| What | 3 | 2 | 1 |
|---|---|---|---|
| Gun blur copies drawn | 12 | 6 | 3 |
| Of those, with arms | 4 | 2 | 0 |
| Arm blur copies (cards out) | 8 | 4 | 2 |
| Blur copies of each card | 6 | 3 | 1 |
| Coins in a kill | 30 | 18 | 10 |
| Passes each coin's lines are drawn | 3 | 2 | 1 |
| Sparks, streaks and bolts in a hit | all | 60% | 35% |
| Outpost trail copies | every stamp | every 2nd | every 4th |

Fewer blur copies are each drawn a little stronger and still cover the same trail, so the blur thins out, not shortens.

## What changed for everyone

- **Arm blur copies of the gun's blur** are on a third of the gun's copies at most, not all of them. Posing a pair of arms is the dearest thing a copy does.
- **A still hand costs nothing.** With the cards out, no arm copy is posed or placed unless some part of the arms has moved enough to blur, and the 192 card copies aren't touched unless some are out.
- **Blur copies' transparency** is only set when it changes.
- **Hit effects reuse their parts** (up to 240 kept), and a streak's shape is only set when it changes, not every frame.
- **Lighter guns.** The lever rifle went from 52 to 35 thousand triangles and the AK from 34 to 25 thousand, by thinning tiny screws and pins, the AK's butt plate and muzzle brake, and tightening the rifle's budgets (`tools/build_lever_rifle.py`). Both were checked by eye from three angles in Blender and swapped in at the same size and place.
- **Gun and arm meshes** use box collision, since nothing collides with them.

## Not done

- Nothing is measured. The next step is to look at the frame rate and `PerfLevel` on a weak machine, with the F9 and Shift+F5 readouts, and see which of the above matters.
- The soldier arms are 84 separate mesh parts; their triangle count hasn't been looked at.
- Each player and the first-person arms carry a Highlight outline, which is costly on weak graphics chips. It's part of the look, so it was left.
- Bloom and colour grading are left to Roblox, which drops them itself at low quality.
- Other players' bodies and held guns are posed every frame however far away they are.
- Phones: touch controls, and a look at memory.
