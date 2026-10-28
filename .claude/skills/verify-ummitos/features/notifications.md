# Notifications

The shell is the session's notification server. A notification shows as a toast at the top right. It stays in a history panel grouped by app, which opens from the bar's bell or by IPC.

## Sub-features

- `notif-toast`: a notification sent over D-Bus shows as a toast with app name, summary and body.
- `notif-panel`: the panel lists the same notification under its app.
- `notif-clear`: Clear empties the history.
- `notif-dnd`: Do not disturb stops toasts, while the history still records them.

## How to get to it (user POV)

- Any app sends a notification (`notify-send`, a browser, a chat app).
- Click the bell in the bar, or call `notifications toggle` (bound to no key by default).

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The panel is closed.

Steps:

- **Send.** Run `.claude/skills/verify-ummitos/scripts/run.sh timeout 10 notify-send -a Verify "Hello from verify-ummitos" "Body line"`. Exit code 0.
- **Toast.** Wait about 1 s, then run `.claude/skills/verify-ummitos/scripts/shot.sh notif-toast`. The top right shows a card with `Verify`, `Hello from verify-ummitos` and `Body line`.
- **Panel.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications toggle`, wait about 1 s, then run `.claude/skills/verify-ummitos/scripts/shot.sh notif-panel`. The panel titled `Notifications` shows the group `Verify` with the same entry. Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications toggle` again to close it.
- **Clear.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications clear`, then reopen the panel and take a screenshot. The panel shows its empty state.
- **DND.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications dnd` and send another notification. No toast appears, and the panel lists it. Run `dnd` again to turn it off.

## Gotchas

- Hyprland draws a red "started without start-hyprland" banner only if the stack was not started through `start-hyprland`. `up.sh` uses it; an old stack may still show the banner over the top of the screen.
- History is in memory only. No state file is written, so the proof is the panel, not a file.
- Notification sounds are silent: the stack has no PipeWire.
