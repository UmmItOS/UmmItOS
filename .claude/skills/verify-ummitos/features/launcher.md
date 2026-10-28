# Launcher

Super+Return opens a search over installed apps; Enter launches the top match. Alt+V opens the clipboard manager over cliphist history.

## Sub-features

- `launch-open`: the launcher opens focused, with a search field.
- `launch-search`: typing filters the list.
- `launch-run`: Enter starts the selected desktop entry.
- `launch-clipboard`: the clipboard view lists cliphist entries.

## How to get to it (user POV)

- Super+Return, which calls `launcher apps`.
- Alt+V, which calls `launcher clipboard`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- No launcher is open.

Steps:

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh launcher apps`, then `.claude/skills/verify-ummitos/scripts/shot.sh launch-open`. The full-screen launcher shows the app list.
- **Search.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype kitty`, then `.claude/skills/verify-ummitos/scripts/shot.sh launch-search`. The list narrows to entries matching `kitty`.
- **Run.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Return`, then `.claude/skills/verify-ummitos/scripts/run.sh hyprctl -j clients`. A `kitty` client exists in the nested compositor. Close it with `.claude/skills/verify-ummitos/scripts/run.sh hyprctl dispatch 'hl.dsp.window.close()'`.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh launcher close` (or `wtype -k Escape`). `hyprctl -j layers` no longer lists `ummitos-launcher`.

## Gotchas

- Desktop entries come from `XDG_DATA_DIRS` (`/usr/share`). The fake HOME has no `~/.local/share/applications`, so user-only entries are missing.
- Launch counts are written under the fake HOME's state path, not the real `~`.
- The clipboard view needs a cliphist database. The fake HOME has none, so it shows its empty state, and that empty state is a valid result.
