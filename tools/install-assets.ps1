# Copies assets/sounds and assets/textures into the newest Studio install so rbxasset files load.
# The same job as install-sounds.sh, for Windows PowerShell. Roblox replaces those folders when
# Studio updates, so run this again after an update.
#   powershell -ExecutionPolicy Bypass -File tools\install-assets.ps1
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\RobloxStudioBeta.exe" |
	Sort-Object LastWriteTime -Descending |
	Select-Object -First 1
if (-not $studio) {
	Write-Error "Roblox Studio isn't installed for this user."
}
$content = Join-Path $studio.DirectoryName "content"
foreach ($kind in "sounds", "textures") {
	$target = Join-Path $content "$kind\deckshooter"
	New-Item -ItemType Directory -Force -Path $target | Out-Null
	Copy-Item (Join-Path $repo "assets\$kind\*") $target -Force
	Write-Output "Installed $kind to $target"
}
