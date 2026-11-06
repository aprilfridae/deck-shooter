# Deck Shooter

Roblox PvP deck-building shooter. GitHub is the source of truth for code.

## Setting up a new computer

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the pinned Rojo and Lune.
2. Install the Studio plugin: `rojo plugin install`.
3. Copy the sounds and textures into Studio. On Windows:

       powershell -ExecutionPolicy Bypass -File tools\install-assets.ps1

   With a bash shell, `sh tools/install-sounds.sh` does the same. Run it again after every Studio update, because updates delete those files.

## Live sync into Studio

    rojo serve

In Studio, open the place and stay in edit mode, then Plugins > Rojo > Connect. Connecting during a Play test fails with "Http requests can only be executed by game server". Saved code changes then appear in Studio.

## Tests

    lune run tests/run.luau

## Build a place file

    mkdir build
    rojo build -o build/DeckShooter.rbxl
