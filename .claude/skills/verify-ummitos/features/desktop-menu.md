# Desktop menu

A right-click on the empty desktop opens a small menu titled "Desktop" at the pointer (`background/DesktopMenu.qml`, a `Flyout`). It has three actions, "Displays…", "Wallpaper…" and "Settings", and then a "Show on desktop" group of switches: Weather card, Now playing card, Activate Linux and FPS counter.

## Sub-features

- `menu-open`: a right-click shows the menu at the pointer, and a left click elsewhere closes it.
- `menu-actions`: Displays… opens the display chooser (`ummitos-displays`), Wallpaper… opens the wallpaper drawer (`ummitos-wallpaper-browser`), and Settings opens Settings.
- `menu-switches`: a switch row flips its widget, saves to `~/.config/ummitos/desktop.conf` (`weather=`, `media=`, `activate=`, `fps=`) and keeps the menu open.
- `menu-keys`: Up and Down (and Tab) move a purple focus bar along the rows and wrap. Space or Return activates the row. Escape closes.

## How to get to it (user POV)

- Right-click on any empty part of the desktop.

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`, and no window covers the click point.

Steps (proven 2026-11-04):

- **Open.** Run `run.sh hyprctl dispatch 'hl.dsp.cursor.move({ x = 700, y = 600 })'`, then `run.sh wlrctl pointer move 5 5` and `run.sh wlrctl pointer click right`. `shot.sh menu-open` shows "Desktop" and the rows.
- **Keys.** Press `run.sh wtype -k Down` four times. The focus bar sits on "Weather card". `run.sh wtype -k space` flips it: `grep weather $STACK/home/.config/ummitos/desktop.conf` changes between `1` and `0`, and the menu stays open.
- **Action.** The seven rows wrap: from "Weather card", four more Down land on "Displays…" and five on "Wallpaper…". Return opens `ummitos-displays` or `ummitos-wallpaper-browser`, as `run.sh hyprctl -j layers` shows. Close what opened before the next journey; `wallpaper browse` toggles, so a drawer left open is shut by the next call.
- **Escape.** With the menu open, `run.sh wtype -k Escape` closes it.
- **Wallpaper….** Click it, about 90 px right and 107 px below the click point. The drawer opens (see wallpaper.md).

## Gotchas

- Real motion (`wlrctl pointer move`) must come before the right-click, or the desktop may not get the press.
- The switches carry `Accessible.ignored`, because the row is the checkbox. Do not count the switches as separate stops.
