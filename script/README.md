# script

Helper scripts copied to `~/script`. The desktop shell itself lives in
`configs/quickshell`; what remains here is what the shell, Hyprland keybinds and
hyprlock call out to.

| Path | Called by |
|------|-----------|
| `hotkey-tui.sh` | the bar's keyboard button |
| `cliphist/clip-store.sh` | `wl-paste --watch` in `exec.conf` |
| `hypr/hyprlock/` | `hyprlock.conf` — battery, distro and update readouts |
| `hypr/hyprpicker/hyprpicker.sh` | Alt+P |
| `misc/first-run.sh` | `exec.conf`, once per user |
| `misc/update.sh` | the bar's update button |
| `misc/clipboard-history.sh` | `update.sh`, to offer clearing cliphist |
| `misc/wf-recorder.sh` | Super+Shift+R |
| `misc/convert-extensions.sh` | run by hand, normalises wallpaper extensions |

Scripts log to a `.log` file beside themselves. Check the log rather than relying
on the notification, which only reports the last run.
