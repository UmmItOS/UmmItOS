# Notifications

The shell is the session's notification server. A notification shows as a toast at the top right, which times out after 6 s; a critical one stays. Every non-transient notification is kept in a history panel, grouped by app. The panel opens from the bar's bell or by IPC.

## Sub-features

- `notif-toast`: a notification sent over D-Bus shows as a toast with the app name, the time, the summary and the body.
- `notif-panel`: the panel lists it under its app, with a count next to the title.
- `notif-clear`: clearing the history leaves "Nothing here.". IPC `clear` acts at once; the panel button is a two-step "Clear all" / "Clear all?".
- `notif-dnd`: with Do not disturb on, no toast appears, the bell shows `notifications_off`, and the history still records the notification.

## How to get to it (user POV)

- Any app sends a notification (`notify-send`, a browser, a chat app).
- Click the bell in the bar, or use IPC `notifications toggle | close | clear | dnd`. No key is bound by default.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The panel is closed.
- About 8 s have passed since `up.sh`, so the start-up health-check toast has gone (see Gotchas).

Steps (all proven 2026-10-29):

- **Send.** Run `.claude/skills/verify-ummitos/scripts/run.sh timeout 10 notify-send -a Verify "Hello from verify-ummitos" "Body line"`. The exit code is 0.
- **Toast.** Wait about 1 s, then run `.claude/skills/verify-ummitos/scripts/shot.sh notif-toast`. The top right shows a card with `Verify`, `Hello from verify-ummitos` and `Body line`.
- **Panel.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications toggle`, wait about 1 s, then `.claude/skills/verify-ummitos/scripts/shot.sh notif-panel`. "Notifications 1" shows the group `Verify` with the same entry. A toast less than 6 s old is still up, moved left of the panel. Close with `.claude/skills/verify-ummitos/scripts/ipc.sh notifications close`.
- **Clear.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications clear`, reopen the panel and take a shot. Expect "Nothing here.", then close it.
- **DND.** Wait 7 s so the earlier toasts expire. Run `.claude/skills/verify-ummitos/scripts/ipc.sh notifications dnd`, send "DND test", and take a shot: no new toast, and the bell is struck through. Open the panel: "DND test" is listed. Close it and run `dnd` again.

## Gotchas

- History is only in memory, with no state file. A hot reload (any QML save) wipes it and every open toast, so wait for a new `Configuration Loaded` before you start.
- Transient notifications (`notify-send -e`) toast but never reach the history.
- In the test stack the health check runs at start and posts "1 things need attention" from `UmmItOS`, because the fake HOME has no `~/script`. Expect it in the panel; this run showed it twice.
- Sounds are silent: the chime goes through `pw-play`, and the stack has no PipeWire.
