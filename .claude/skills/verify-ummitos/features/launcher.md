# Launcher

Super+Return opens a full-screen search over installed apps; Enter launches the top match. Alt+V opens the clipboard manager over the cliphist history.

## Sub-features

- `launch-open`: the launcher (`ummitos-launcher`) opens with focus in its search field.
- `launch-search`: typing filters the list, ranking name prefix, then word start, then substring, then keywords.
- `launch-run`: Enter starts the top match and closes the launcher.
- `launch-clipboard`: the clipboard view (`ummitos-clipboard`) lists the cliphist entries.

## How to get to it (user POV)

- Super+Return, which calls `launcher apps`. Calling it again toggles it shut.
- Alt+V, which calls `launcher clipboard`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- No launcher is open.
- The pointer is parked with `.claude/skills/verify-ummitos/scripts/run.sh hyprctl dispatch 'hl.dsp.cursor.move({ x = 960, y = 540 })'`.

Steps (all proven 2026-10-29):

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh launcher apps`, then `.claude/skills/verify-ummitos/scripts/shot.sh launch-open`. `hyprctl -j layers` lists `ummitos-launcher`.
- **Search.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype kitty`, then `.claude/skills/verify-ummitos/scripts/shot.sh launch-search`. The query reads `kitty`, the caption says "1 match, Enter to open", and one kitty tile is left.
- **Run.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Return`, wait 2 s, then `.claude/skills/verify-ummitos/scripts/run.sh hyprctl -j clients`. A `kitty` client is listed, and the launcher layer is gone.
- **Close kitty.** Run `.claude/skills/verify-ummitos/scripts/run.sh hyprctl dispatch 'hl.dsp.focus({ window = "class:kitty" })'`, then `.claude/skills/verify-ummitos/scripts/run.sh hyprctl dispatch 'hl.dsp.window.close()'`, then `.claude/skills/verify-ummitos/scripts/run.sh wtype y`, which answers kitty's "close this OS window?" prompt. The client list is empty.
- **Clipboard.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh launcher clipboard`, then take a shot. It shows "Clipboard is empty" and the layer `ummitos-clipboard`. Run `.claude/skills/verify-ummitos/scripts/ipc.sh launcher close`; neither layer remains.

## Gotchas

- Desktop entries come from `/usr/share/applications`. The fake HOME has none of its own.
- kitty runs zsh, which shows its new-user wizard in the fake HOME. Close kitty with the steps above; a plain close leaves a confirmation prompt open, and that window then shrinks later screens, which made the QR scan fail.
- Launch counts go to the fake HOME's state path, not to the real `~`.
- With no cliphist database, the clipboard view shows "Clipboard is empty". If clipboard history is turned off, it reads "Clipboard history is off" instead.
