# Picture converter

Super+I opens a GTA-style wheel. Pictures dropped on it can be converted to one of eight formats, and a MISSION PASSED or FAILED banner reports the result.

## Sub-features

- `conv-open`: the wheel (`ummitos-convert`) shows eight slots clockwise from the top: PNG, JPG, WEBP, AVIF, GIF, BMP, TIFF, ICO. The hub reads "Drop pictures here" over "From a browser or a file manager".
- `conv-pick`: Right, Down and Tab move the lit slot clockwise; Left, Up and Backtab move it back. Hovering a slot and the scroll wheel move it too.
- `conv-drop`: a dropped file fills the hub with its name; several files flip with PageUp and PageDown.
- `conv-run`: clicking a slot, or pressing Return, Enter or Space after a drop, converts and shows the banner.

## How to get to it (user POV)

- Super+I, which calls `convert toggle`. Escape, or `convert close`, closes it, except while a conversion runs.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The wheel is closed.
- The pointer is parked on the hub with `.claude/skills/verify-ummitos/scripts/run.sh hyprctl dispatch 'hl.dsp.cursor.move({ x = 960, y = 540 })'`, so hover cannot move the lit slot.

Steps (proven 2026-10-29):

- **Open.** Run `timeout 5 .claude/skills/verify-ummitos/scripts/ipc.sh convert toggle`, then `.claude/skills/verify-ummitos/scripts/shot.sh conv-open`. Note which slot is lit.
- **Pick.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Right`, then `.claude/skills/verify-ummitos/scripts/shot.sh conv-right`. The lit slot moves one step clockwise, for example PNG to JPG. Keys reach the wheel with no click. Then run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Tab`, `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Left` and `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Up` and take a shot: the net is one step back.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Escape`. After about 1 s, `hyprctl -j layers` has no `ummitos-convert`.

## Gotchas

- The lit slot carries over between opens; it is reset only by a fresh shell load. Always take a shot before the key, not only after.
- A drop needs a real Wayland drag, and `wtype` cannot drag. IPC offers only toggle and close. The ydotool + `qs -p` drag-source harness in the repo's CLAUDE.md moves the user's real pointer, so `conv-drop` and `conv-run` are not provable with these helpers.
- Running `convert toggle` while a MISSION banner is still up reuses the mapped surface. Keys may not arrive until a click (inferred from source, not proven).
