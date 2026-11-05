# Wallpaper pickers

There are two pickers over the one `Wallpapers` singleton. Alt+W opens a keyboard carousel along the bottom (`ummitos-wallpaper-picker`). A right-click on the desktop, then "Wallpaper…", opens a mouse drawer on the right edge (`ummitos-wallpaper-browser`). Opening one closes the other.

## Sub-features

- `wall-carousel`: Alt+W shows the cards along the bottom. Left and Right move, Return sets, Escape closes, and typing filters.
- `wall-drawer`: the drawer has the title "Wallpaper", a caption "N pictures · hover to preview, click to set", Shuffle and Close buttons, and a row of folder chips over a two-column grid of named thumbnails.
- `wall-current`: the current wallpaper's thumbnail has a check badge, and its name is in the accent colour.
- `wall-chips`: "All" plus the top-level folders. Picking a folder that has subfolders adds a second row ("↳ Alya", "Alya/Old"). A folder chip shows its whole subtree.
- `wall-preview`: hovering a thumbnail shows that wallpaper on the desktop behind the drawer. Escape, × or a click outside restores the wallpaper that was set.
- `wall-set`: a click sets the wallpaper and closes the drawer.
- `wall-shuffle`: the Shuffle button's tip reads "Shuffle <folder>". Each press picks a random wallpaper from that folder and makes it the bar's shuffle pool.

## How to get to it (user POV)

- Alt+W for the carousel (`qs -c ummitos ipc call wallpaper toggle`).
- Right-click on the empty desktop, then "Wallpaper…", for the drawer (`ipc call wallpaper browse`).

## Driving it with verify-ummitos

Preconditions:

- `doctor.sh` is all `ok`.
- The stack has no `~/.wallpaper`. Make one, with a nested folder:

  ```sh
  source .claude/skills/verify-ummitos/scripts/env.sh; W=$STACK/home/.wallpaper
  mkdir -p $W/Anime/Alya $W/Land
  for c in red gold; do magick -size 640x360 gradient:$c-black $W/Land/$c.jpg; done
  magick -size 640x360 gradient:purple-navy $W/Anime/a.jpg; magick -size 640x360 plasma:fractal $W/Anime/Alya/b.jpg
  ```

Steps (proven 2026-11-06):

- **Drawer.** Run `ipc.sh wallpaper browse`, wait 1.5 s, then `shot.sh wall-drawer`. The drawer is on the right, from x ≈ 1465 to the edge. `run.sh hyprctl -j layers` lists `ummitos-wallpaper-browser`.
- **Chips.** Warp to the "Anime" chip (about 1560,150), send `run.sh wlrctl pointer move 1 1`, then `run.sh wlrctl pointer click left`. The caption reads "2 pictures", the grid shows `a` and `b` (b is from Alya), and a second row shows "↳ Alya".
- **Preview.** Warp onto a thumbnail and send real motion (`wlrctl pointer move 4 4`). After about 1 s the desktop shows that picture.
- **Set.** Click a thumbnail. `ipc.sh wallpaper get` prints its path, and the drawer is gone.
- **Restore.** Open again, hover a thumbnail, then `run.sh wtype -k Escape`. `ipc.sh wallpaper get` is unchanged, and the desktop shows it again.
- **Shuffle.** Hover the shuffle icon (about 1838,95): its tip reads "Shuffle All". Clicking it changes `wallpaper get`.
- **Carousel.** Run `ipc.sh wallpaper toggle`, then `shot.sh wall-carousel`. The cards run along the bottom with the name and "N of M" bottom-left. Escape closes it.

## Gotchas

- `hyprctl dispatch hl.dsp.cursor.move` only warps the pointer. Send `wlrctl pointer move` before expecting hover or a preview, because hover is gated on real motion.
- The tooltip under the header buttons is small. Crop the screenshot to read it.
- The drawer is one window with no screen set, so Hyprland puts it on the focused output. Multi-monitor placement is not proven.
