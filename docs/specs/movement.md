# Movement

**Status:** built. Checked against the code on 2026-11-05.

**Values live in:** `src/shared/Movement/MoveConfig.luau` for the moves and the speed limits. Camera values are at the top of `src/client/Movement.client.luau`, the edge check's reach and headroom in `src/client/Ledge.luau`, and the cheat check's timings at the top of `src/server/MovementGuard.server.luau`. The grace times come from `src/shared/CardCore/Config.luau` (dash and push) and `src/server/Outpost/Outpost.server.luau` (travel).

## How it works

- Each player's client moves its own Humanoid. `src/client/Movement.client.luau` runs the pure rules in `src/shared/Movement/MoveState.luau` every frame. Roblox Server Authority was considered and declined.
- The camera is locked to first person (`StarterPlayer.CameraMode = LockFirstPerson`). Gravity is 150 for a slower arc. Both are set in `default.project.json`.
- The character turns with the camera every frame. The client sends its pose (Normal, Crouch or Slide) to the server, which stores it as the character's `MovePose` attribute. `src/client/RemotePoses.client.luau` draws every body in stop-motion at 12 frames per second, matching the arms' run clips, with the poses in `src/shared/Movement/BodyPose.luau`: crouching (root joint lowered 1.5 studs, knees bent) and sliding (lowered 1.5 studs and tilted back 50 degrees). Each joint also twitches every held frame, like the arms but 3 times stronger so it reads from a distance. Only the root part collides with the world. In the Outpost, your own body gets the guns' motion blur: faded copies between held poses (`src/client/BodySmear.client.luau`).
- Only `src/client/Input.luau` reads keys, so touch and controller can be added later.
- Movement never changes accuracy. You can shoot in every move except a climb, which also puts a held card away.

## Keys

These are the defaults. Players can rebind all but W, A, S and D in Settings (`outpost-ui.md`).

| Key | Action |
| --- | --- |
| W, A, S, D | Move (Roblox's default controls) |
| Left Shift | Sprint |
| C or Left Ctrl | Crouch, slide, fast fall |
| Space | Jump, edge parry, climb |

## Moves

Speeds are studs per second.

| Move | Rule |
| --- | --- |
| Walk | 16 |
| Crouch | 8 |
| Sprint | 24, in any direction, with no stamina |
| Slide | Crouch while sprinting. Starts at 42 and slows to 24 over 0.9s, then holds 24 for as long as crouch is held. No cooldown. The direction is fixed when the slide starts. Letting go of crouch blends back to walk or sprint speed over 0.25s. |
| Jump | 6 studs high |
| Slide jump | Jumping out of a slide adds 8 to the current speed. The air keeps that speed, and it fades over 0.6s after landing. |
| Fast fall | Hold crouch in the air to fall faster: 350 per second per second, up to 110. Landing while moving with crouch and sprint held starts a slide. |
| Chain jump | A jump from a slide that began by landing from the air goes 8 studs high and adds 16. |
| Edge parry | Press jump at a fixed flat edge 1 to 4.5 studs above the feet, on the ground or in the air. Keeps the current speed (at least 24) and adds 6, up to 58. It goes in the slide direction while sliding (or in the air after a slide with no move key held), otherwise the move direction, otherwise the camera's. |
| Climb | Hold jump facing a fixed flat edge 4.5 to 12 studs above the feet, with 5.5 studs of headroom on top. Takes 0.35s (65% of it rising) and ends at sprint speed. "Facing" is the camera's flat look direction. |

A **fixed flat edge** is an anchored part that isn't part of a character, with a top surface whose normal points at least 0.98 up. The edge check looks 1.5, 2.5 and 3.5 studs ahead (`src/client/Ledge.luau`).

## Camera

- Field of view is 80. It eases (rate 7) to 88 in a slide, 84 in a jump, 96 in a slide jump and 104 in a chain jump, and back to 80 on landing.
- Aiming the Longscope sets field of view 30, which overrides all of the above.
- A slide drops the camera 2 studs.
- Landing after at least 0.15s in the air dips the camera 0.9 studs.

## Sounds

- A footstep plays every 9 studs while walking or sprinting, and a jump sound plays when a jump starts. `docs/sound-list.md` lists what's missing (landing, slide, parry, climb).
- Roblox's default running sound is muted on every character.

## Cheat checks

The server checks every player's movement in `src/server/MovementGuard.server.luau`, using `src/shared/Movement/SpeedLimit.luau`.

- **One limit for every state.** This is deliberate: a client could fake its state, and slide jumps legally hold high speed. Horizontal movement may be at most 63 studs per second (the fastest chain jump plus a margin) times the time passed, plus 4 studs for lag. Rising may be at most 60 per second times the time passed, plus 4. Both are measured from the oldest sample in a 0.5s window, and one jump in position is credited with at most 1.3s.
- Falling is never checked. Hovering isn't detected.
- Checks run every 0.1s, with 1s of grace after spawning.
- Moves the server causes pause the check through `MoveGrace.give`: Phase Dash for 1s, an Aegis Shell push for 0.5s and Outpost travel for 1s, each plus twice the player's ping.
- A failed check moves the player back to their last valid position and adds a strike. Checks then pause for 0.25s, or twice the ping plus 0.1s if that's longer, so the move-back can reach the client.
- 5 strikes kick the player from the server with "Removed for unusual movement." and a server `warn`. There are no bans. Strikes survive respawns and clear when the player leaves. Once matches exist, strikes should remove the player from the match instead (see `matches.md`).
- The pose remote accepts only Normal, Crouch and Slide, at most 10 per second.
