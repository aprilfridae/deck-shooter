# Brings River's working copy up to date: pulls main and downloads the latest release's place file.
#   powershell -ExecutionPolicy Bypass -File tools\pull-latest.ps1
# Uses the GitHub CLI. If it isn't logged in, it borrows the login Git Credential Manager already
# saved, for this run only.
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

if (git status --short) {
	Write-Error "There are uncommitted changes here. Commit or stash them before pulling."
}
git checkout -q main
git pull -q --ff-only origin main
Write-Output "main is at $(git log --oneline -1)"

$borrowed = $false
gh auth status *> $null
if ($LASTEXITCODE -ne 0 -and -not $env:GH_TOKEN) {
	$saved = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
	$env:GH_TOKEN = ($saved | Where-Object { $_ -like "password=*" }) -replace "^password=", ""
	$borrowed = $true
}
try {
	$tag = gh release list --repo aprilfridae/deck-shooter --limit 1 --json tagName --jq ".[0].tagName"
	gh release download $tag --repo aprilfridae/deck-shooter --pattern "SplitDeck.rbxl" --dir $repo --clobber
	Write-Output "Downloaded SplitDeck.rbxl from $tag"
} finally {
	if ($borrowed) {
		Remove-Item Env:\GH_TOKEN
	}
}
