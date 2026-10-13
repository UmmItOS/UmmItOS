# How to release

1. **Check that everything is pushed.** `git rev-list --count origin/master..HEAD` should print `0`, and the worktree should be clean.

2. **Bump `VERSION`.**
   - A release candidate sets `RC = -rcN` and `NAME = UmmItOS vX.Y.Z-rcN`.
   - A final release leaves `RC = ` empty and sets `NAME = UmmItOS vX.Y.Z`.
   - Edit only `MAJOR`, `MINOR`, `PATCH`, `RC` and `NAME`.

3. **Commit, then tag.** Both are GPG-signed through the git config (`commit.gpgsign`, `tag.gpgsign`).
   ```sh
   git commit -am "UmmItOS vX.Y.Z"
   git tag -s vX.Y.Z -m "UmmItOS vX.Y.Z"
   git tag -v vX.Y.Z    # must say "Good signature"
   ```

4. **Write the release note** in a scratch file, never in the repo. Base it on `git log --format=%s vPREV..HEAD`, and follow the layout of the earlier releases (`gh release view vPREV`):
   - one short summary paragraph
   - `## New`, grouped by area
   - `## Security`
   - `## Fixes`
   - `## Install notes`:
     - new packages (`git diff vPREV HEAD -- install/packages_*`)
     - new submodules (`.gitmodules`)
     - new shortcuts (`configs/hypr/hyprland/shortcuts.lua`)
     - anything a user must run again
   - `**Full Changelog**: https://github.com/UmmItOS/UmmItOS/compare/vPREV...vX.Y.Z`

5. **Push, then publish.**
   ```sh
   git push origin master vX.Y.Z
   gh release create vX.Y.Z --title vX.Y.Z --notes-file <note.md> --verify-tag --latest
   ```
   Add `--prerelease` for a release candidate only if you want it marked as one; the rcs so far were published as normal releases.

6. **Check it.** Run `gh release list -L 2`. Fix the wording later with `gh release edit vX.Y.Z --notes-file <note.md>`.
