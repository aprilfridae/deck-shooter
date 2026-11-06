# Deck Shooter

Roblox PvP deck-building shooter. GitHub is the source of truth for code.

## Setting up a new computer

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder. It installs the pinned Rojo and Lune.
2. Install the Studio plugin: `rojo plugin install`.
3. Copy the sounds into Studio. On Windows:

       powershell -ExecutionPolicy Bypass -File tools\install-assets.ps1

   With a bash shell, `sh tools/install-sounds.sh` does the same. Run it again after every Studio update, because updates delete those files. The sounds are uploaded to River's Roblox account, but Roblox only lets uploaded audio play in experiences River owns. In River's experience the game uses the uploaded sounds; in any other place it falls back to these local copies, so without this step that place is silent. Textures and models are already uploaded or in the repo.

## Live sync into Studio

    rojo serve

In Studio, open the place and stay in edit mode, then Plugins > Rojo > Connect. Connecting during a Play test fails with "Http requests can only be executed by game server". Saved code changes then appear in Studio.

Rojo also sets up everything else the game needs from the repo: the gun, arm and card models, the lighting and its effects, and the settings for Workspace, Players, StarterPlayer, StarterGui and SoundService. A blank place synced with Rojo matches the main one.

Experience settings (Game Settings in Studio, such as avatar type and access to API services) aren't part of a place, so Rojo can't sync them. Without "Enable Studio Access to API Services", card saves use a temporary store that resets each session.

## Tests

    lune run tests/run.luau

## Build a place file

    mkdir build
    rojo build -o build/DeckShooter.rbxl
