# Movement

**Status:** built. Checked against the code on 2026-11-07. Climbing was removed on 2026-11-07.

**Values live in:** `src/shared/Movement/MoveConfig.luau` for the moves and the speed limits. Camera values are at the top of `src/client/Movement.client.luau`, the edge check's reach and headroom in `src/client/Ledge.luau`, and the cheat check's timings at the top of `src/server/MovementGuard.server.luau`. The grace times come from `src/shared/CardCore/Config.luau` (dash and push) and `src/server/Outpost/Outpost.server.luau` (travel).

## How it works

- Each player's client moves its own Humanoid. `src/client/Movement.client.luau` runs the pure rules in `src/shared/Movement/MoveState.luau` every frame. Roblox Server Authority was considered and declined.
- The camera is locked to first person (`StarterPlayer.CameraMode = LockFirstPerson`). Gravity is 75 (River lowered it from 150 on 2026-11-10; Roblox's own is 196.2), for a slow, floaty arc: jumps reach the same heights and take about 1.4 times as long as they did at 150. Both are set in `default.project.json`.
- The character turns with the camera every frame. The client sends its pose (Normal, Crouch or Slide) to the server, which stores it as the character's `MovePose` attribute. `src/client/RemotePoses.client.luau` draws every body. Soldier bodies ease toward their gun pose every frame, at full framerate. Other bodies use the poses in `src/shared/Movement/BodyPose.luau`: crouching (root joint lowered 1.5 studs, knees bent) and sliding (lowered 1.5 studs and tilted back 50 degrees). Bodies don't jitter: that stays on the first-person arms only. Only the root part collides with the world.
- Soldier bodies (the character model has the attribute `SoldierRig = true`) show gun poses from the pose files instead of the crouch and slide layers. `src/shared/Movement/BodyPoses/` holds one module per gun (made by `tools/build_body_poses.py` from `tools/export_body_poses.py`'s JSON; don't edit by hand) plus `Empty` for no gun, which also holds the soldier rig's joints (`rig`, root 3 studs above the feet). `src/shared/Movement/GunStance.luau` picks the pose each held frame: Reload, then Slide, Jump_Up or Fall in the air, Land for 0.25 seconds, Fire for 0.17 seconds after a shot, then a four-beat stride (contact, pass, then both with the legs mirrored) for crouch walk, walk and sprint (20 studs per second and up), else Stand or Crouch_Idle. Sidearms without poses use the Energy Pistol's. `src/client/HeldGuns.luau` puts the gun model in the hand, sized to the pose file's gun, and moves the magazine and charging handle or pump with the pose; your own held gun always hides in locked first person (the slide pose moves the head away from the camera, so distance alone wasn't enough). Bodies with no player, such as the soldier test dummy, are posed too: they carry the `PosedBody` tag and name their gun with a `GunId` attribute. A body's gun goes when the body is destroyed or leaves the game (a replaced body is only taken out, not destroyed). Fingers don't move in third person.
- Only `src/client/Input.luau` reads keys, so touch and controller can be added later.
- Movement never changes accuracy. You can shoot in every move.

## Keys

These are the defaults. Players can rebind all but W, A, S and D in Settings (`outpost-ui.md`).

| Key | Action |
| --- | --- |
| W, A, S, D | Move (Roblox's default controls) |
| Left Shift or C | Crouch, slide (defaults since 2026-11-11; were C and Left Ctrl). Sprint has no key: moving is always sprinting, and its binding was taken out of settings. Saves still on the old default keys move to the new ones (`cleanKeys` in `Settings.luau`). |
| Space | Jump, edge parry |

## Moves

Speeds are studs per second.

| Move | Rule |
| --- | --- |
| Walk | Gone for players since 2026-11-10 (auto-sprint). The 15 in `MoveConfig` is only the standing-still mode's speed now. |
| Response | 2026-11-11: River got stuck in surfaces just by walking into them. The cause was this feature setting the velocity into a wall every frame. Now a wall within 1.5 studs ahead (a blockcast of the root part) takes the into-the-wall part out of the goal, and if the velocity was set last frame and the body still isn't moving that way, nothing more is set until the keys change (`WALL_FEEL`, `STALL_SHARE`, `lastPush` in `Movement.client.luau`). Not tried in Play. On 2026-11-11 River had the air steering taken out ("perfect air strafing ... doesn't feel right"): in the air the game no longer sets the velocity toward the keys, `AirResponse` is gone, and only the Humanoid's own air control is left; the ground and takeoff parts below stay. Not tried in Play. Added 2026-11-10, not tried in Play. The move keys take hold at once: `onFrame` in `Movement.client.luau` sets the flat velocity itself, straight to the keys on the ground (and to a stop with none held) and quickly toward them in the air (`AirResponse`). Air with no keys held is left alone. River found the Humanoid's own easing felt like thick air. | Later the same day River still found it mushy and saw a stutter on slide boosts: the air now follows the keys faster (`AirResponse` 30, was 14), a jump's speed is there the moment you leave the ground, and a slide that loses the ground for under 0.3s (`SlideBlip`) carries on slowing instead of starting again at full speed, which had made the speed lurch. Not tried in Play, and the stutter's cause is a best guess. The velocity is only set when it is more than 1.5 off (`ResponseSlack`): setting it every frame made the camera judder, which River caught on video; Roblox seems to stop smoothing a body on frames a script sets its velocity. Don't write a character's velocity every frame.
| Camera smoothing | Added 2026-11-10, not confirmed in Play. `src/client/CameraSmooth.luau`, called first thing in `Guns.client.luau`'s frame. Roblox draws a character where its last 240-a-second physics step left it, so at frame rates 240 doesn't divide by, the first-person camera moves in uneven jumps. Measured live at about 160 frames a second: 0.25 and 0.125 studs by turns. This is what River reported as stutter and as lag. The camera is shifted to a position advanced by velocity times the frame's length and eased back to the true one. |
| Crouch | 6 |
| Sprint | 18.5 (30, then 27, 20, 16.5 and 18.5 on 2026-11-10: River wants the game way less fast paced, and playable on phones; every speed here came down with it), in any direction, with no stamina |
| Slide | Crouch while sprinting. Builds from sprint speed up toward 31 over 0.18s (`SlideRampTime`, added 2026-11-11: River wanted it to come on slower, a little like Call of Duty; not tried in Play), peaking near 29, and slows to sprint speed (18.5) over 0.9s, then holds it for as long as crouch is held. No cooldown. The direction is fixed when the slide starts. Letting go of crouch blends back to walk or sprint speed over 0.25s. |
| Jump | 6 studs high |
| Cards in hand | Added 2026-11-11, not tried in Play. While the cards are out, walk, sprint, crouch and slide speeds are 15% higher (`CardSpeed` 1.15 in `MoveConfig.luau`; sprint 18.5 becomes about 21.3). The air keeps the speed you left the ground with. The server speed limit went from 43 to 48 to allow it. |
| Slide jump | Jumping out of a slide adds 3.5 to the current speed. The air keeps that speed, and it fades over 0.6s after landing. |
| Fast fall | Removed 2026-11-10 (River no longer wanted holding crouch in the air to pull you down). Landing while moving with crouch and sprint held still starts a slide. |
| Chain jump | A jump from a slide that began by landing from the air adds 6.5 to the current speed, more than a plain slide jump. It goes no higher than any other jump: it used to reach 8 studs, and River had that taken out on 2026-11-10. |
| Wall jump | Press jump in the air with a wall within 2.4 studs (any side; it mustn't lean more than a little). The wall is looked for at three heights (body middle, 2.2 below, 1.5 above; 2026-11-11, not tried in Play) so low walls and walls with windows count. Kicks off it: away from the wall and toward where the player is steering or looking (bounced off the wall if that points into it), rising 6.5 studs. Keeps the current speed (at least sprint speed) and adds 5, up to 37.5 (5 studs and 2 until 2026-11-11, when River asked for more push). Up to 3 in one time in the air, at least 0.25s apart, never off the same wall twice running, and not in the first 0.12s of a jump. An edge parry wins if both could happen. Plays a heavy metal impact (`wall-jump.wav`) and bursts dust, chips and orange sparks off the wall where you kicked (`src/client/WallKick.luau`); only you see and hear your own. The sound and burst are from 2026-11-11 and not tried in Play. (`MoveState.wallJump`, `tryWallJump` in `Movement.client.luau`; values in `MoveConfig`.) |
| Edge parry | Press jump at a fixed flat edge 1 to 4.5 studs above the feet, on the ground or in the air. Keeps the current speed (at least sprint speed, 18.5) and adds 3.5, up to 37.5. It goes in the slide direction while sliding (or in the air after a slide with no move key held), otherwise the move direction, otherwise the camera's. |

A **fixed flat edge** is an anchored part that isn't part of a character, with a top surface whose normal points at least 0.98 up. The edge check looks 1.5, 2.5 and 3.5 studs ahead (`src/client/Ledge.luau`).

## Camera

- Field of view is 80. It eases (rate 7) to 88 in a slide, 84 in a jump, 96 in a slide jump and 104 in a chain jump, and back to 80 on landing.
- Aiming the Longscope sets field of view 30, which overrides all of the above.
- The camera sits level with the soldier's eye bar, 0.94 above Roblox's default spot and 0.5 forward of the root, so it can't poke through walls (`BODY_CAMERA`).
- A slide drops the camera 2 studs.
- Landing after at least 0.15s in the air dips the camera 0.9 studs.

## Sounds

- A footstep plays every 9 studs while walking or sprinting, and a jump sound plays when a jump starts.
- Landing after at least 0.15s in the air plays a landing sound: the hard one if the fall reached 60 studs per second (a long drop), else the soft one. `HardLandSpeed` in `MoveConfig.luau`.
- Every slide plays the slide start sound as it begins, including one started by landing, so a landing into a slide plays both.
- `docs/sound-list.md` lists what's still missing, such as the slide loop and the parry.
- Roblox's default running sound is muted on every character.

## Cheat checks

The server checks every player's movement in `src/server/MovementGuard.server.luau`, using `src/shared/Movement/SpeedLimit.luau`.

- **One limit for every state.** This is deliberate: a client could fake its state, and slide jumps legally hold high speed. Horizontal movement may be at most 43 studs per second (the fastest chain jump plus a margin) times the time passed, plus 4 studs for lag. Rising may be at most 60 per second times the time passed, plus 4. Both are measured from the oldest sample in a 0.5s window, and one jump in position is credited with at most 1.3s.
- Falling is never checked. Hovering isn't detected.
- Checks run every 0.1s, with 1s of grace after spawning.
- Moves the server causes pause the check through `MoveGrace.give`: Phase Dash for 1s, an Aegis Shell push for 0.5s and Outpost travel for 1s, each plus twice the player's ping.
- A failed check moves the player back to their last valid position and adds a strike. Checks then pause for 0.25s, or twice the ping plus 0.1s if that's longer, so the move-back can reach the client.
- 5 strikes kick the player from the server with "Removed for unusual movement." and a server `warn`. There are no bans. Strikes survive respawns and clear when the player leaves. Once matches exist, strikes should remove the player from the match instead (see `matches.md`).
- The pose remote accepts only Normal, Crouch and Slide, at most 10 per second.
