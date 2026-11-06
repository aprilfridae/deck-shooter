# Split Deck

Roblox PvP deck-building shooter. This repo holds the code only, synced into Studio with Rojo.
The design docs start at [`docs/README.md`](docs/README.md), and [`docs/HANDOFF.md`](docs/HANDOFF.md) says where things stand.
The repo and the Rojo project still use the game's old name, Deck-Shooter.
Everything else lives with the Fridae Studios group on Roblox:

- **The place:** the group's SplitDeck experience. It holds the gun, arm and card models
  (`ReplicatedStorage.GunModels`), the lighting and its effects, and the place settings.
- **Sounds, textures and font sheets:** group assets. Their ids are in
  `src/shared/Guns/SoundIds.luau`, `src/shared/Guns/OutpostAssets.luau` and `src/shared/Guns/Hud/FontImages.luau`.
  Uploaded audio only plays in experiences the group owns, so work in the group's experience.

## Setting up a new computer

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the pinned Rojo and Lune.
2. Install the Studio plugin: `rojo plugin install`.
3. Ask to be added to the Fridae Studios group with a role that can edit its experiences.

## Live sync into Studio

    rojo serve

In Studio, open the group's SplitDeck experience and stay in edit mode, then Plugins > Rojo > Connect.
Connecting during a Play test fails with "Http requests can only be executed by game server".
Saved code changes then appear in Studio. Rojo leaves the models, lighting and other place content alone.

## Adding a sound or image

Upload it to the group with a group API key, then put its id in the matching file above:

    python tools/upload-group-assets.py results.json path/to/new-sound.wav

The script reads the key from the `ROBLOX_GROUP_API_KEY` environment variable.

## Tests

    lune run tests/run.luau

## Build a place file

Build on top of the group's published place, so the models, lighting and settings come with it:

    python tools/download-place.py build/base.rbxl
    lune run tools/build-place build/base.rbxl

The download needs a user API key with the Legacy Asset permission in `ROBLOX_API_KEY`; Roblox refuses that permission on group keys.
Without a key, `lune run tools/build-place` builds from local exports in `assets/models/` instead.
Both write `build/SplitDeck.rbxl`. Place files go in GitHub releases, never in commits.

To get the latest `main` and the latest release's place file:

    powershell -ExecutionPolicy Bypass -File tools\pull-latest.ps1
