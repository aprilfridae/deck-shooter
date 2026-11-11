# Radio

**Status:** built on 2026-11-10 from the design agreed with River the same day; not seen or heard in Play. River's 23 tracks were uploaded to the group on 2026-11-10 and Roblox's moderation removed many of them, for swearing among other things, so River had all of them taken out of the playlist the same day. A second set of 20 (mostly Olswel and Syzy, converted from m4a to mp3) was uploaded later that day and is the track list now; each plays once Roblox clears it, and any it removes are skipped. The next set needs clean or instrumental versions: Roblox rejects songs with swearing or other adult content. Two things differ from the design below and are marked where they come up: the visualizer uses the loudness bars (the real-spectrum trial hasn't been run), and the HUD pieces are named in "How it's built".

## The idea

A personal radio, in the style of the one in NBA 2K's park: your music plays while you're in the Outpost and on PvP maps, and a small strip on the HUD shows what's on, with a live visualizer. Each player controls their own radio. Nobody else hears it or is affected by it.

**Done means:** River's tracks play back to back in the Outpost and on a PvP map without restarting on travel; next, previous and on/off work from their keys; the strip shows the right title and artist and its bars move with the music; and River signs off on the look and feel in Play.

## What River decided

| Question | Decision |
| --- | --- |
| Who hears what | Personal. Each player has their own radio. |
| Where the music comes from | River's own tracks, uploaded to the group like the game's other sounds. |
| How tracks are organised | One playlist, shuffled. No stations. |
| Controls | Next track, previous track, radio on/off. Volume stays on the existing Music slider. |
| On the HUD | Always on screen, everywhere, as a corner strip: bars on the left, title and artist stacked beside them, top-left. |

## How it plays

- **Shuffle:** every track plays once, in a random order, before any repeats. A new shuffle never starts with the track that just ended.
- **Next and previous:** next moves on in the shuffled order. Previous restarts the current track if it's more than 3 seconds in, otherwise goes back one track. History is kept for this visit only.
- **When it starts:** after `PLAY` on the title screen. The menu music stays as it is and fades out as it does now; the radio fades in after it.
- **Travel:** moving between the Outpost, the test room and maps doesn't restart or change the track.
- **Death and respawn:** the radio carries on.
- **Volume:** the Music slider in settings, through the same sound group the menu music uses.
- **On/off:** off pauses the track where it is; on resumes it. The choice is saved with the player's other settings.
- **A track that fails to load** (still in moderation, or removed) is skipped without stopping the radio.

## Controls

Three new bindings in settings, rebindable like the others.

| Action | Default key |
| --- | --- |
| Next track | `.` |
| Previous track | `,` |
| Radio on/off | `M` |

No touch buttons yet. They come with the phone controls.

## The HUD strip

- **Place:** top-left corner, in the Outpost and on PvP maps. Health, ammo and cards sit along the bottom and the Outpost menu is bottom-left, so the top-left is free. It hides with the rest of the HUD behind the title screen and while dead (the death screen owns the picture then).
- **Layout:** nine bars about as tall as the two lines of text, then the title above the artist. The game's own lettering (`TypeLabel`): the title in `LabelBold`, the artist in `Label`, dimmer.
- **Colour:** teal bars with every third bar orange, Bone text. Maps keep a teal and orange look.
- **On a new track** (a skip, going back, or a song ending): the current title and artist slide left off the screen, then the new ones slide in from the left edge and settle into place. The bars stay where they are. The text is cropped at the bars' edge, so it disappears there as if going behind them and never crosses them, and the new text comes out from that same edge (River, after seeing it: the visualizer counts as "off the screen"). About 0.25 seconds out and 0.35 in, easing to a stop. River asked for this slide on 2026-11-10; it replaces the earlier idea of typing the title in. The strip is at full brightness for the change, then settles to a dimmer look after about 4 seconds so it stays out of the way in a fight.
- **Radio off:** the strip shrinks to a small `RADIO OFF` tag with flat bars.

## The visualizer

**As built:** the fallback. The bars use `MusicBars` on the track's `PlaybackLoudness`, 20 times a second. The real-spectrum trial needs a Play session to run in and hasn't been done; it's the next thing to try.

- **First choice:** real frequency bars. Roblox's newer audio instances (`AudioPlayer` wired to an `AudioAnalyzer`) can report a spectrum, so the bars would follow the bass and treble. This is to be proven first, in a small trial, because the game's other sounds use the older `Sound` instances.
- **Fallback:** what the title screen does today: `MusicBars`, which shares one loudness number across the bars with a moving pattern. If the trial fails or costs too much, the radio uses this and nothing else changes.
- Either way the bars update a few times a second, not every frame, and stop when the radio is off.

## How it's built

All on the client. The server has no part in it: the radio is personal, so there is nothing to keep in step and nothing to abuse.

| Piece | Where | What it does |
| --- | --- | --- |
| Track list | `src/shared/Guns/RadioTracks.luau` | Title, artist and sound for each track. Adding a song is one upload and one line. |
| Playlist rules | `src/shared/Guns/Radio.luau` | Pure: the shuffle, next, previous, and what to do when a track fails. Tested under Lune. |
| Player | `src/client/RadioPlayer.client.luau` | Plays the current track, moves on when it ends, reads the keys, saves on/off. |
| Strip | `src/client/RadioHud.luau` | Draws the strip and the bars. Called from the player. |
| Settings | `PlayerSettings`, `SettingsPanel`, `Input` | The three bindings and the saved on/off. |

## What River needs to give

A folder of the tracks, and the title and artist for each. They're uploaded to the group with `tools/upload-group-assets.py`, and each waits on Roblox's moderation before it plays.

## Left out for now

Stations, voting, other players hearing your radio, a track list screen, touch buttons, and different music by place. None of them is ruled out; they were left out to keep the first version small.

## Risks

| Risk | What's planned |
| --- | --- |
| The real-spectrum visualizer doesn't work with the game's sounds | Trial it first; fall back to the loudness bars |
| Tracks sit in moderation for a while | A failed track is skipped; the radio works with whatever has cleared |
| Music fights with footsteps and gunfire | It's on the Music slider, separate from Game volume; the default level is for River to judge |
| An always-on strip clutters fights | It dims after a track change; option B from the mock-ups (a one-line ticker) is the fallback look |
