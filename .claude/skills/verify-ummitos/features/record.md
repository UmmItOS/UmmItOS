# Screen recording

Super+Shift+R runs `script/misc/screen-record.sh`. With no recording running, it asks the shell for the recording dialog (`record/RecordWindow.qml`): system sound and microphone checkboxes, Cancel and Start. Start counts down, then the script runs `gpu-screen-recorder -w portal -restore-portal-session yes`, so the desktop portal asks which screen to share before the first recording and remembers the answer. A pill with the elapsed time sits on the bar while it records. Super+Shift+R again stops it and a "Recording saved" notice names the file. The options (quality, frame rate, codec, cursor, folder) are on Settings → Record and live in `~/.config/ummitos/recording.conf`.

## Sub-features

- `rec-dialog`: `record open` shows "Screen recording" with "System sound" (ticked by default) and "Microphone", and S and M toggle them. Its layer is `ummitos-record`.
- `rec-settings`: Settings → Record writes `quality=`, `fps=`, `codec=` and `cursor=` to `recording.conf`.
- `rec-run`: the portal picker, the recording, the bar pill and the saved file. **Not reachable in this stack**: the portal's screencast needs PipeWire, and the stack has none (gsr stops at `CreateSession`). Prove it on the live session: Super+Shift+R, Start, pick the screen, stop after a few seconds, and check the file with `ffprobe`.

## How to get to it (user POV)

- Super+Shift+R, or "Start recording" on Settings → Record.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.

Steps (proven 2026-11-18):

- **Dialog.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh record open`, wait about 1 s, then `.claude/skills/verify-ummitos/scripts/shot.sh record-dialog`. Expect the dialog above. `.claude/skills/verify-ummitos/scripts/ipc.sh record close` closes it.
- **Settings.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh settings page 0` for the Record page. Click a Quality or Codec segment (real pointer motion first) and `grep` the stack's `~/.config/ummitos/recording.conf`.

## Gotchas

- Do not press Start in the stack: the script calls the real `gpu-screen-recorder`, and with no PipeWire the portal never answers.
- The bar pill starts when gpu-screen-recorder creates the file, which it does only after the portal picker is answered. Cancelling the picker gives a "Recording did not start" notice.
