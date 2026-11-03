# Display chooser

Super+P opens a panel (`ummitos-displays`) with four mode cards: This screen only, Duplicate, Extend, Second screen only. The current mode is lit and the connected outputs are listed. After a change, a confirm row asks "Keep these display settings?" with Revert and Keep; without Keep the old layout returns after 15 s. A detached watchdog restores it even if the shell dies.

## Sub-features

- `displays-open`: `displays toggle` opens the panel, with the current mode card lit and the outputs listed.
- `displays-keys`: Left and Right move the selection and wrap around the four cards; Return applies; Escape closes.
- `displays-apply`: applying writes the revert script to `$STACK/run/ummitos-displays-revert-<HYPRLAND_INSTANCE_SIGNATURE>.lua` and shows the confirm row with "Reverting in %1 s".
- `displays-revert`: 15 s without Keep restores the outputs and deletes the revert file.
- `displays-watchdog`: if the shell dies mid-confirm, the detached watchdog restores the outputs about 15 s later.
- `displays-menu`: right-click on empty desktop shows a "Desktop" menu with "Displays…", "Wallpaper…" and "Settings" (`background/DesktopMenu.qml`).

## How to get to it (user POV)

- Super+P, which calls `displays toggle` (`configs/hypr/hyprland/shortcuts.lua`).
- Right-click on empty desktop, then "Displays…".

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- A second output. Run `.claude/skills/verify-ummitos/scripts/run.sh hyprctl output create headless VERIFY2`, then `.claude/skills/verify-ummitos/scripts/run.sh hyprctl eval 'hl.monitor({ output = "VERIFY2", disabled = false, mirror = "", mode = "1280x720@60", position = "auto-right", scale = 1 })'`, and wait about 6 s.
- Read state with `.claude/skills/verify-ummitos/scripts/run.sh hyprctl -j monitors all`. `mirrorOf` is the source monitor's numeric id, `"none"` when not mirroring.

Steps (proven 2026-11-04):

- **Open.** Run `.claude/skills/verify-ummitos/scripts/ipc.sh displays toggle`, then `.claude/skills/verify-ummitos/scripts/shot.sh displays-open`. `run.sh hyprctl -j layers` lists `ummitos-displays`; Extend is lit and the outputs are listed.
- **Keys.** `run.sh wtype -k Left` or `-k Right` moves the selection and wraps around the four cards.
- **Apply Duplicate.** From Extend, send Left, then `run.sh wtype -k Return`. VERIFY2 gets `mirrorOf` = the VERIFY id and position 0,0. The confirm row shows "Reverting in %1 s", and `$STACK/run/ummitos-displays-revert-<HYPRLAND_INSTANCE_SIGNATURE>.lua` exists (source `scripts/env.sh` for `$STACK`).
- **Second screen only.** From Extend, Right then Return: VERIFY is off, VERIFY2 on at 0,0, never both off. 15 s later both are back.
- **Twice in a row.** A second apply after a revert writes a fresh revert file again (it carries a timestamp line at the end).
- **Auto-revert.** Wait 15 s without Keep. VERIFY2 is back at 1920,0, `mirrorOf` is `"none"`, and the revert file is gone.
- **Desktop menu.** Move the pointer: `run.sh hyprctl dispatch 'hl.dsp.cursor.move({ x = 700, y = 600 })'`. Run `run.sh wlrctl pointer click right`, then `shot.sh displays-menu`: a menu titled "Desktop" with "Displays…", "Wallpaper…", "Settings" sits at the pointer. Click "Displays…" (pointer about 90 px right and 72 px below the click point) and the panel opens. A left click elsewhere closes the menu.
- **Watchdog (last; ends the journey).** Apply Duplicate, then at once run `source .claude/skills/verify-ummitos/scripts/env.sh; kill -- -$(cat $STACK/qs.pid)`. About 15 s later the outputs are reverted and the revert file is gone. The test shell is dead afterwards: run `down.sh`, then `up.sh`.

## Gotchas

- The stack lists a disabled WAYLAND-1 output (harness artifact). It counts as a connected, switched-off output.
- The Keep button cannot be clicked reliably from the harness. Keep is proven only by reading the code (`Displays.qml` `keep()`), not on screen.
- Never drive this on the live session: it changes the real monitors.
- The change is runtime only. A Hyprland config reload restores the config's monitors.
