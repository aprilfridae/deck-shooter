# Deck Shooter

Roblox PvP deck-building shooter (Split Deck). This repo holds the code only, synced into Studio with Rojo.
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

    mkdir build
    rojo build -o build/DeckShooter.rbxl

A built place has the code only, not the models or assets, which live in the group's place.
