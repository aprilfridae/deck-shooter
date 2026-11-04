#!/bin/sh
# Copies assets/sounds into the running Studio install so rbxasset sounds play.
# Roblox replaces that folder when Studio updates, so run this again after an update.
cd "$(dirname "$0")/.." || exit 1
installed=$(ls "$LOCALAPPDATA"/Roblox/Versions/*/RobloxStudioBeta.exe | xargs -d '\n' ls -t | head -1)
target="$(dirname "$installed")/content/sounds/deckshooter"
mkdir -p "$target" && cp assets/sounds/* "$target/" && echo "Installed to $target"
