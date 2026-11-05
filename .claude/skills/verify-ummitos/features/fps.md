# FPS counter

A frame-rate card in the top-left corner of each screen, like Counter-Strike's `cl_showfps 1/0`. It sits on the Bottom layer with the weather card, so windows and every shell surface cover it.

## Sub-features

- `fps-on`: the card (`ummitos-fps`) shows a speed icon, the number of frames the shell swaps per second and a dim "FPS". On the stack's 60 Hz `VERIFY` output it reads 60.
- `fps-off`: off unmaps the card after its fade.
- `fps-save`: the choice is saved as `fps=1` or `fps=0` in `~/.config/ummitos/desktop.conf`.

## How to get to it (user POV)

- Settings → Misc → Show FPS, the desktop right-click menu's "FPS counter" switch, or `qs -c ummitos ipc call fps set 1` (`set 0`, `toggle`). No key is bound.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- No window covers the top-left corner.

Steps (proven 2026-11-01):

- **On.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh fps set 1`, wait 1.5 s, then `.claude/skills/verify-ummitos/scripts/shot.sh fps-on`. The card reads 60. `grep fps "$STACK/home/.config/ummitos/desktop.conf"` prints `fps=1`.
- **Off.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh fps toggle`. After about 1.2 s, `run.sh hyprctl -j layers` has no `ummitos-fps`.

## Gotchas

- The number counts frames the compositor lets the card draw, so it never passes the refresh rate. A window over the card lowers it, which nobody sees.
- A reload does not move a shown card to another layer; hide and show it, or restart the test shell, after changing its layer.
