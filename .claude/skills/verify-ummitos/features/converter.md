# Picture converter

Super+I opens a GTA-style wheel. Pictures dropped on it can be converted to one of eight formats, and a MISSION PASSED or FAILED banner reports the result.

## Sub-features

- `conv-open`: the wheel opens with eight slots and the drop hint.
- `conv-pick`: the arrow keys and Tab move the lit slot.
- `conv-drop`: dropping a file fills the hub with its name.
- `conv-run`: clicking a slot converts the file and shows the banner.

## How to get to it (user POV)

- Super+I, which calls `convert toggle`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The wheel is closed.

Steps:

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh convert toggle`, then `.claude/skills/verify-ummitos/scripts/shot.sh conv-open`. The wheel shows PNG, JPG, WEBP, AVIF, GIF, BMP, TIFF and ICO around "Drop pictures here".
- **Pick.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Right`, then `.claude/skills/verify-ummitos/scripts/shot.sh conv-pick`. The next slot is lit.
- **Close.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Escape` (or `.claude/skills/verify-ummitos/scripts/ipc.sh convert close`). The wheel fades out.

## Gotchas

- A drop needs a real Wayland drag source and pointer button events, and `wtype` cannot drag. The repo's CLAUDE.md "Picture converter" section shows a ydotool + `qs -p` drag-source harness. That harness moves the user's real pointer, so it only belongs in a session where that is acceptable. `conv-drop` and `conv-run` are not provable with these helpers alone.
- The wheel's keyboard focus is OnDemand: keys reach it only after it has focus, and that happens when it opens.
