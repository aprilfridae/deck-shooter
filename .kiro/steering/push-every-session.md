# Push every session to GitHub

River's rule: every coding session ends with its work on GitHub, so the repo always has the latest build of the game.

- When a coding task is finished and checked, and before the session ends, put every change on `main` at `aprilfridae/deck-shooter`.
- Run the tests first (`lune run tests/run.luau`). If they fail, fix them or tell River before pushing.
- Work on a `feature/<topic>` branch, merge it into `main` with `--no-ff`, then push both `main` and the branch.
- Confirm local `main` matches `origin/main` and that `git status` is clean, then tell River it's pushed.
- The repo is code only. Never commit `assets/`, place files or API keys. Sounds, images and models live with the Fridae Studios group on Roblox.
- If a session changed nothing, there's nothing to push.
