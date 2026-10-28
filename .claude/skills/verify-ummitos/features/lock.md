# Lock screen

Super+L locks the session with an ext-session-lock surface on every screen. Only a correct password unlocks it; the shell's own PAM stack is `configs/quickshell/lock/pam/password`, a single `auth required pam_unix.so` line.

## Sub-features

- `lock-preview`: `lock preview` shows the lock content in an ordinary window, and calling it again closes it.
- `lock-engage`: `lock lock` takes a grim capture of the screen and then locks. `isLocked` prints `true`.
- `lock-wrong`: a wrong password turns the field red, shakes it and shows "Wrong password · attempt 1".
- `lock-alarm`: the second wrong password starts the intruder alarm: overlay, siren, a live webcam and a 30 s clip. **Never drive this sub-feature**; `ipc.sh lock alarm` is refused.

## How to get to it (user POV)

- Super+L, which calls `lock lock`.
- hypridle: `lock_cmd`, and before sleep through `loginctl lock-session`. The idle listener runs `detect_vm.sh`.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- `.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked` prints `false`.
- Drive the lock **last**, because nothing in the stack can unlock it.

Steps:

- **Preview.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview`, wait about 1 s, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-preview`. Expect the date, a big clock, the avatar, the user name and "Enter your password to unlock". The password field stays hidden until you type. Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview` again and take a shot; the preview is gone.
- **Engage.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock lock`, then poll: `timeout 5 sh -c 'until [ "$(.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked)" = true ]; do sleep 0.2; done'`. After 1 more second run `.claude/skills/verify-ummitos/scripts/shot.sh lock-engaged`.
- **One wrong password.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype "not-the-password"`, then `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Return`, **once**. Wait about 3.5 s for pam_unix's failure delay, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-wrong`. Expect the red "Wrong password · attempt 1" (proven 2026-10-29). If it has not shown yet, take another shot; never send Return again.
- **End.** Run `.claude/skills/verify-ummitos/scripts/down.sh`. It removes the nested compositor, and its lock goes with it.

## Gotchas

- Never type or ask for the user's real password. Unlocking cannot be proven in this stack.
- **Never send a second wrong password, and never call `lock alarm`.** Either one sets `intruder`, and that loads a Qt `Camera` inside the test shell itself (`Lock.qml`). `ipc.sh` refuses `lock alarm`; the second wrong password is only covered by `up.sh` masking `/dev/video*` and `/dev/media*` with `/dev/null` for the test `qs` (via `bwrap`), which is unproven against a real camera node. The clip from `script/misc/intruder.sh` lands in the fake HOME and dies with `down.sh`.
- While PAM checks the password, the field is disabled, and keys typed meanwhile are dropped.
- `isLocked` turns true when the shell sets `locked`, not when the compositor confirms the lock. Prove the lock with the screenshot.
- The shell's PAM stack has no `pam_faillock`, so test attempts do not count against the account.
