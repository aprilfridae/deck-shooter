#!/bin/sh
# Copies assets/sounds and assets/textures into the running Studio install so rbxasset files load.
# Roblox replaces those folders when Studio updates, so run this again after an update.
cd "$(dirname "$0")/.." || exit 1
installed=$(ls "$LOCALAPPDATA"/Roblox/Versions/*/RobloxStudioBeta.exe | xargs -d '\n' ls -t | head -1)
content="$(dirname "$installed")/content"
mkdir -p "$content/sounds/deckshooter" && cp assets/sounds/* "$content/sounds/deckshooter/" && echo "Installed sounds to $content/sounds/deckshooter"
mkdir -p "$content/textures/deckshooter" && cp assets/textures/* "$content/textures/deckshooter/" && echo "Installed textures to $content/textures/deckshooter"
