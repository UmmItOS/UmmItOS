# script

Helper scripts copied to `~/script`. The desktop shell itself lives in
`configs/quickshell`; what remains here is what the shell, Hyprland keybinds and
hypridle call out to.

| Path | Called by |
|------|-----------|
| `cliphist/clip-store.sh` | `wl-paste --watch` in `autostart.lua`: stores each copy (unless history is off or the item is marked sensitive), schedules its expiry, tells the shell what was copied |
| `cliphist/clipboard-expiry.sh` | `clip-store.sh` and the Settings → Privacy page: `schedule`, `enforce`, `expire`, `cancel` and `clear` (history and the live clipboard) |
| `hypr/lock/detect_vm.sh` | `hypridle.conf`, locks on idle unless a QEMU guest is running |
| `hypr/hyprpicker/hyprpicker.sh` | Alt+P |
| `misc/first-run.sh` | `autostart.lua`, once per user |
| `misc/update.sh` | the bar's update button, Super+Shift+Return, the update reminder: a terminal menu to tick pacman, AUR, oh-my-zsh and flatpak (only what is installed), with an auto-yes toggle per row |
| `misc/install-packages.sh` | the Settings → Packages page, with the packages it found missing |
| `misc/ocr-index.sh` | the screenshot gallery on open, and each new screenshot: reads the text inside pictures into a SQLite table the gallery searches |
| `misc/launch.sh` | every `run()` in `shortcuts.lua`: names the missing program in a notice |
| `misc/screen-record.sh` | Super+Shift+R, through the shell's recording dialog |
| `misc/mic-check.sh` | `screen-record.sh` and the shell after each wake; fails when the mic is stuck |
| `misc/_ui.sh` | sourced by `update.sh` and `install-packages.sh`: colours, `print_status`, and `say`, which sends a notice through the shell (with its sound) |

Scripts send their results as notices with `notify-send -a "<App name>"`, never
`hyprctl notify`. Most also log to a `.log` file beside themselves (git ignores
them): check it rather than relying on the notification, which only reports the
last run.
