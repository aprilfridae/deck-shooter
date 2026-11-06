# Every session: pull request, then a place build

River's rule: every coding session ends with its work merged through a pull request and a fresh place build on GitHub. Pull requests keep people working at the same time from overwriting each other.

## Pull request

- Work on a `feature/<topic>` branch. Never push to `main` directly.
- Run the tests (`lune run tests/run.luau`). If they fail, fix them or tell River before merging.
- Before merging, bring in the latest `main` (`git fetch` then `git merge origin/main`), fix any conflicts and rerun the tests.
- Push the branch, open a pull request into `main` with `gh pr create`, and merge it with `gh pr merge --merge`.
- Update local `main` (`git checkout main` then `git pull`), and confirm it matches `origin/main` and `git status` is clean.

## Place build

- After the merge, build the game from `main` on top of the group's published place:
  - `python tools/download-place.py build/base.rbxl` (needs a user API key with the Legacy Asset permission in `ROBLOX_API_KEY`; group keys are refused)
  - `lune run tools/build-place build/base.rbxl`
- Without a key, `lune run tools/build-place` builds from the local exports in `assets/models/` instead. Say so in the release notes.
- Both write `build/SplitDeck.rbxl`.
- Publish it as a GitHub release on `main`, tagged `build-YYYY-MM-DD-HHMM`, with the place file attached: `gh release create <tag> build/SplitDeck.rbxl --target main --title "<tag>" --notes "<what changed>"`.
- The place file goes in the release, never in a commit.

## Always

- The repo is code only. Never commit `assets/`, place files or API keys. Sounds, images and models live with the Fridae Studios group on Roblox.
- If a session changed nothing, there's nothing to merge or build.
