# Lock screen

Super+L locks the session with an ext-session-lock surface on every screen. Only a correct password (PAM `pam_unix`) unlocks it.

## Sub-features

- `lock-engage`: `lock lock` captures the screen, then locks. `isLocked` returns true.
- `lock-preview`: `lock preview` shows the same content in an ordinary window; calling it again closes it.
- `lock-wrong`: a wrong password shows the error state. The second wrong one starts the intruder alarm.

## How to get to it (user POV)

- Super+L, which calls `lock lock`.
- hypridle after idle, and before sleep.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- `.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked` prints `false`.

Steps:

- **Preview.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview`, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-preview`. The lock content is shown: clock, password field, and the weather card when it has data. Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock preview` again to close it.
- **Engage.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh lock lock`, wait about 2 s, then run `.claude/skills/verify-ummitos/scripts/ipc.sh lock isLocked`. It prints `true`. Run `.claude/skills/verify-ummitos/scripts/shot.sh lock-engaged`.
- **Wrong password.** Run `.claude/skills/verify-ummitos/scripts/run.sh wtype "not-the-password"` and `.claude/skills/verify-ummitos/scripts/run.sh wtype -k Return`, then `.claude/skills/verify-ummitos/scripts/shot.sh lock-wrong`. The field shows the failure state. Stop after one wrong attempt.
- **End.** You cannot unlock without the user's real password. End the journey with `down.sh`, which removes the nested compositor and its lock with it.

## Gotchas

- Never type the user's real password, and never ask for it. `lock-unlock` cannot be proven in this stack.
- A second wrong password starts the intruder alarm. The webcam script resolves to `<repo>/script/misc/intruder.sh`, which would open the real camera. Stop after one wrong attempt.
- The lock uses PAM for the real user, so the account's faillock state applies.
