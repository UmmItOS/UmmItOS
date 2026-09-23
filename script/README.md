# script

Helper scripts copied to `~/script`. The desktop shell itself lives in
`configs/quickshell`; what remains here is what the shell, Hyprland keybinds and
hypridle call out to.

| Path | Called by |
|------|-----------|
| `cliphist/clip-store.sh` | `wl-paste --watch` in `autostart.lua` |
| `hypr/lock/detect_vm.sh` | `hypridle.conf`, locks on idle unless a QEMU guest is running |
| `hypr/hyprpicker/hyprpicker.sh` | Alt+P |
| `misc/first-run.sh` | `autostart.lua`, once per user |
| `misc/update.sh` | the bar's update button |
| `misc/clear-clipboard.sh` | `update.sh`, offers to wipe the cliphist history |
| `misc/wf-recorder.sh` | Super+Shift+R |

Scripts log to a `.log` file beside themselves. Check the log rather than relying
on the notification, which only reports the last run.
