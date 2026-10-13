# Review: 2026-10-11 to 2026-10-13

The 40 commits from `af68600~1` to `455eb67` (46 files, about 3,600 lines): battery logger and screen, intruder alarm and camera, Wi-Fi and Bluetooth dialogs, Wi-Fi page and counter, network label, hover tips, weather card stepping aside, Settings sheet, Misc page.

Four reviews ran in parallel, one per lens in CHECKLIST.md:

- **Ponytail (ultra):** over-engineering, duplication, dead code.
- **QML:** bindings, lifetimes, performance, property order.
- **Hallmark:** UI, UX, motion, states, translation.
- **Bugs and security:** stuck states, races, privacy, injection.

Every finding below was checked against the code. Two that did not hold up are listed at the end.

Severity: **High** fix soon · **Medium** fix in the next pass · **Low** fix when touching the file.

## High

### H1. The webcam can stay on after unlock
`configs/quickshell/lock/Lock.qml` · found by QML and bugs

`filming = true` is set right after `recorder.record()`. It is cleared only when the recorder reports Stopped. If `record()` fails at once (output not writable, no encoder, camera busy), the state never leaves Stopped, so `filming` stays true. The camera Loader (`active: intruder || filming`) then keeps the webcam open, with its light on, after unlock until the shell restarts. No error handler exists.

**Fix:** derive it: `filming: recorder.recorderState !== MediaRecorder.StoppedState`, or clear it in `onErrorOccurred` and when `clipEnd` fires.

### H2. The Bluetooth dialog can answer for the wrong device
`configs/quickshell/bar/BtAsk.qml:33-41` · found by bugs (medium confidence)

- **Wrong name:** the device name is guessed (the first device that is pairing, else the first one connecting). It is not read from bluetoothctl's prompt. With two devices in flight, the dialog can show your headphones' name while it asks about another device.
- **Wrong answer:** a second prompt replaces the open dialog, but the single "yes" goes to whichever prompt bluetoothctl is waiting on.

**Fix:**
- Read the device address from bluetoothctl's line before the question, and look the name up by address.
- While a dialog is open, answer any new prompt "no".

### H3. Eight translation keys nothing uses
`configs/quickshell/i18n/zh-HK.json`, `zh-TW.json` · found by ponytail

Left over from a dropped battery view:
- "Plugged in now; pick another range"
- "%1% · %2 Wh"
- "~ estimated while plugged in, from your battery minutes"
- "Used on battery"
- "%1 Wh in %2"
- "%1% avg"
- "~%1% · %2 Wh"
- "%1 · %2 W avg"

**Fix:** delete them from both files.

## Medium

### M1. The Wi-Fi history is a trace that Wipe cannot clear
`configs/quickshell/services/WifiStats.qml`, `script/misc/wipe-traces.sh`, `settings/WipePage.qml` · found by bugs

`~/.local/state/ummitos/wifi.json` records which networks you joined, how often, and when. CLAUDE.md requires every stored trace to have a `wipe_<name>` function and a card on the Anti-forensics page; this one has neither. Even after the file is shredded, `WifiStats` would write its in-memory copy back on the next network change.

**Fix:**
- Add `wipe_wifi` to `wipe-traces.sh` and a card to the page.
- Add `WifiStats.forget()`, called before the shred like the other in-memory forgets.

### M2. Signal bars disagree between the bar and Settings
`settings/WifiPage.qml:28` vs `bar/Network.qml:32` · found by ponytail

Two `bars()` functions use different thresholds (0.75/0.5/0.25 vs 0.7/0.45/0.15) and different glyph sets, so the same network shows different bars in the two places.

**Fix:** one helper (on `WifiStats`), used by both.

### M3. The siren can spin behind the lock
`lock/Lock.qml` (siren Process) · found by QML

The siren restarts `pw-play` the moment it exits. If `pw-play` fails at once (sound linked to `/dev/null` to silence it, PipeWire down), it respawns in a tight loop while the alarm is up. It also calls `pw-play` directly, against the "every sound goes through `Sounds.play`" rule.

**Fix:**
- Restart only after an exit code of 0, or through a short Timer.
- Give `Sounds` a loop option, or document this file as the exception.

### M4. A shell crash mid-recording can leave the clip unplayable
`lock/Lock.qml` (camera Loader) · found by QML (medium confidence)

A crash or `qs kill` while filming destroys the recorder without `stop()`, so the MP4 is probably never finalised.

**Fix:** record to Matroska (playable when cut short), or call `stopClip()` in `Component.onDestruction`.

### M5. The battery screen can show the wrong range
`power/Power.qml:refresh()` · found by QML

Starting a query while one is still running does nothing. A quick range change (unplug → week) shows the old range's numbers under the new label.

**Fix:** set a `dirty` flag and re-run in `onExited`.

### M6. Copied code
Found by ponytail:

- **Wi-Fi device lookup** in `WifiStats.qml:14`, `ConnectionNotifier.qml:11` and `Network.qml:12`: read `WifiStats.wifi` instead.
- **The cava setup** in `MicCava.qml` is copied from `Cava.qml`: one shared component taking the four values that differ.
- **The wrong-password shake** in `WifiAskWindow.qml:175-220` is copied from `LockContent.qml:281-320`: a small `Shake.qml`.

## Low

| # | Where | Issue | Fix |
|---|---|---|---|
| L1 | `bar/BtAsk.qml:46` | If bluetoothctl exits while the dialog is open, the dialog stays up | `onExited: { root.open = false; retry.start() }` |
| L2 | `bar/WifiAskWindow.qml:31` | The Wi-Fi password stays in the field's memory until the next open (never logged or saved) | clear `psk.text` after submit and cancel |
| L3 | intruder clip | QtMultimedia writes the .mp4 with the shell's umask (0644); only its 700 folder protects it | `chmod 600` the file once it is Stopped |
| L4 | `lock/Lock.qml` | A preview clip can stay in `/run` if a real lock starts while the preview clip is still saving; the preview flag is shared between recordings | delete by the recording's own path |
| L5 | `lock/LockContent.qml`, `Lock.qml` | `cameraView` follows the focused monitor and is never cleared; no live view if focus is on a screen without a lock surface (the clip still records, unlock works) | clear it in the unlock path; pick the lock surface's own screen |
| L6 | `services/MicCava.qml` | A new default microphone is not picked up until cava restarts | restart the Process when its config changes |
| L7 | `bar/Network.qml` (iw parser) | `iw` escapes non-ASCII SSIDs as `\xNN`, so Chinese names get no dBm | decode `\xNN` as UTF-8 |
| L8 | `settings/WifiPage.qml:176` | "joins" is a separate word under the number, against the template rule | `I18n.t("%1 joins").arg(n)` |
| L9 | `bar/Network.qml:348` | `level + " dBm"` joins strings | `I18n.t("%1 dBm").arg(level)` |
| L10 | `bar/NetInfo.qml:79` | "VPN" is raw while "LAN" beside it is translated | `I18n.t("VPN")` |
| L11 | `lock/LockContent.qml:673, 685` | "REC" untranslated; colour `"white"` hardcoded | a `Theme.lock` token; keep "REC" as a universal label on purpose |
| L12 | `lock/LockContent.qml:216` | The lock screen has a `border.width` ring; CLAUDE.md lists only the cheat sheet and SAO as border exceptions | add the lock ring to the list, or remove it |
| L13 | `power/PowerWindow.qml:243`, Doctor lines | Repeater over a rebuilt array: rows rebuild instead of animating; Doctor's `concat` per line is O(n²) | ListView + ScriptModel |
| L14 | `power/Power.qml:6` | Unused import; IpcHandler `target` out of order | remove; move `target` last |
| L15 | app icons | The same `heuristicLookup` + `iconPath` in `PowerWindow.qml:32`, `Workspaces.qml:109`, `UrgentNotifier.qml:49` | one shared function |
| L16 | `services/MicCava.qml:10, 44, 54, 77` | Long comments that restate the code | trim to the non-obvious why |
| L17 | `script/misc/battery-log.sh` | An app name containing `|` splits the drain alert wrongly (SQL is escaped, no injection) | a different separator, e.g. a tab |

## Checked and clean

- **Shell injection:** none. Every command passes data as separate arguments, never inside an `sh -c` string.
- **Parsing:** the `nmcli -t` parsing handles escaped colons.
- **Scripts:** shellcheck passes on `battery-log.sh`, `doctor.sh`, `intruder.sh` and `wipe-traces.sh`.
- **Lock screen:** the siren stops on unlock, nothing gets stuck after a reload, and "Authorize service" is never accepted without asking.
- **Wi-Fi password:** never logged, written to disk or sent as a notice.
- **Shell structure:**
  - Every new singleton is in `qmldir`.
  - `nmcli monitor` runs as the Process itself, so a reload orphans nothing.
  - The `iw` poll and the Wi-Fi page timer only run while shown.
- **Design system:**
  - Every new Theme token is used.
  - Every new `I18n.t` key is in both language files.
  - There are no magic numbers, and all easing comes from `Theme.curve`.
  - Every control has the press scale and pointing-hand cursor.
  - The battery screen's empty and loading states are designed.

## Dropped (did not hold up)

- *"The eye button's label skips `I18n.t()`"*: `BarButton` passes every `label` through `I18n.t` itself (`bar/BarButton.qml:22, 41`).
- *"The Wi-Fi page list has no transitions and no empty state"*: it is a `SettingsList`, which is `SlideList` with add/remove/displaced transitions, and the page shows "No saved Wi-Fi networks" when empty (`settings/WifiPage.qml:90, 96`).

## Not covered

- Nothing was checked on screen in this review; it reads code only.
- `doctor.sh`, `PowerWindow.qml` and `WifiAskWindow.qml` were reviewed in part, not line by line.
- H2 depends on how bluetoothctl queues prompts. Confirm it with two devices before changing the protocol.
