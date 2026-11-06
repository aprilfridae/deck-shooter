# Notes for coding agents

Read `docs/HANDOFF.md` first. It explains the project, how River works, and where things stand.

**Every coding session ends with a pull request and a place build.**

1. Work on a `feature/<topic>` branch, never directly on `main`.
2. When the work is finished, merge the latest `origin/main` into the branch and run `lune run tests/run.luau`. Fix failures before going on.
3. Push the branch, open a pull request into `main` (`gh pr create`) and merge it (`gh pr merge --merge`). Then update local `main` and confirm it matches `origin/main`.
4. Build the place from `main` with `lune run tools/build-place`, and publish `build/SplitDeck.rbxl` as a GitHub release tagged `build-YYYY-MM-DD-HHMM` (`gh release create <tag> build/SplitDeck.rbxl --target main`).

The repo is code only. Never commit `assets/`, place files or API keys. Sounds, images and models live with the Fridae Studios group on Roblox.
