# Lock screen

Super+L locks the session with an ext-session-lock surface on every screen. Only a correct password unlocks it; the shell's own PAM stack is `configs/quickshell/lock/pam/password`, a single `auth required pam_unix.so` line.

## Sub-features

- `lock-preview`: `lock preview` shows the lock content in an ordinary window, and calling it again, or Escape on an empty field, closes it. Its layer is `ummitos-lock-preview`.
- `lock-engage`: `lock lock` takes a grim capture of the screen (or reuses the Wake curtain's earlier picture) and then locks. `isLocked` prints `true`.
- `lock-wrong`: a wrong password turns the field red, shakes it and shows "Wrong password · attempt 1" (the text shows only while the field is empty; seen 2026-11-25).
- `lock-spectrum`: while music plays, Cava's bands rise behind the clock (`lock/LockSpectrum.qml`), mirrored from the middle and coloured from the accent; with nothing playing, or with reduced motion on, the clock stands alone. **Not reachable in this stack**: Cava needs PipeWire (`pactl info` fails in the stack) and a playing MPRIS player. Prove it on the live session with `qs -c ummitos ipc call lock preview` while music plays, taking two `grim` shots apart to see the bars move.
- `lock-alarm`: the second wrong password starts the intruder alarm: overlay, siren, a live webcam and a 30 s clip. While the siren plays it unmutes the default sink every second and holds its volume at `Theme.lock.sirenVolume` (0.6) or above, because the mute and volume keys still work on the lock. **Never drive this sub-feature**; `ipc.sh lock alarm` is refused. The siren command can be proven on its own (see Steps).
- `lock-script`: `script/hypr/lock/lock.sh` is hypridle's `lock_cmd` and what `detect_vm.sh` calls. It locks through IPC and waits for `isLocked`; when no shell is running it starts `qs -c ummitos -d` first, so a dead shell no longer leaves the desktop open.

## How to get to it (user POV)

- Super+L, which calls `lock lock`.
- hypridle: `lock_cmd` (`bash ~/script/hypr/lock/lock.sh`), and before sleep through `loginctl lock-session`. The idle listener runs `detect_vm.sh`, which also calls `lock.sh`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- `.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked` prints `false`.
- Drive the lock **last**, because nothing in the stack can unlock it.

Steps:

- **Preview.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview`, wait about 1 s, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-preview`. Expect the date, a big clock, the avatar, the user name and "Enter your password to unlock". The password field stays hidden until you type. Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview` again and take a shot; the preview is gone.
- **Engage.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock lock`, then poll: `timeout 5 sh -c 'until [ "$(.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked)" = true ]; do sleep 0.2; done'`. After 1 more second run `.claude/skills/verify-ummitos/scripts/shot.sh lock-engaged`.
- **One wrong password.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype "not-the-password"`, then `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Return`, **once**. Wait about 3.5 s for pam_unix's failure delay, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-wrong`. Expect the red "Wrong password · attempt 1" (proven 2026-11-04). If it has not shown yet, take another shot; never send Return again.
- **End.** Run `.claude/skills/verify-ummitos/scripts/down.sh`. It removes the nested compositor, and its lock goes with it.
- **lock.sh with the shell down** (proven 2026-11-18). `lock.sh` names the live config `ummitos`, so run it through a `qs` shim that rewrites that word: write `/tmp/qsshim/qs` as `#!/bin/sh` + `for a; do shift; [ "$a" = ummitos ] && a=ummitos-test; set -- "$@" "$a"; done; exec /usr/bin/qs "$@"` and `chmod +x` it. Then `. scripts/env.sh; in_stack qs kill -c ummitos-test` (not `kill` on `qs.pid`, which only stops the wrapper), and `PATH=/tmp/qsshim:$PATH in_stack bash script/hypr/lock/lock.sh`. Expect exit 0 within about 6 s, `isLocked` `true`, a lock screen in `shot.sh lock-restart`, and one instance in `in_stack qs list -c ummitos-test`. Running it again while locked exits 0 and starts nothing. Then `down.sh`.
- **Siren command** (proven 2026-11-18, outside the shell). Copy the `sh -c` string from the `siren` Process in `lock/Lock.qml` and run it with stub `wpctl` (logs its arguments, answers `Volume: 0.20 [MUTED]`) and `pw-play` (sleeps 2.5 s) first on `PATH`: expect `set-mute … 0` and `set-volume … 0.6` each second, nothing left running after pw-play ends, and no `set-volume` when the stub answers `0.80`.

## Gotchas

- Never type or ask for the user's real password. Unlocking cannot be proven in this stack.
- **Never send a second wrong password, and never call `lock alarm`.** Either one sets `intruder`, and that loads a Qt `Camera` inside the test shell itself (`Lock.qml`). `ipc.sh` refuses `lock alarm`; the second wrong password is only covered by `up.sh` masking `/dev/video*` and `/dev/media*` with `/dev/null` for the test `qs` (via `bwrap`), which is unproven against a real camera node. The clip from `script/misc/intruder.sh` lands in the fake HOME and dies with `down.sh`.
- While PAM checks the password, the field is disabled, and keys typed meanwhile are dropped.
- `isLocked` turns true when the shell sets `locked`, not when the compositor confirms the lock. Prove the lock with the screenshot.
- The shell's PAM stack has no `pam_faillock`, so test attempts do not count against the account.
