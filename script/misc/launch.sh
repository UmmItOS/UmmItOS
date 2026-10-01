#!/usr/bin/env bash
# Runs a keybind's command (hypr/hyprland/shortcuts.lua). When a program it needs is not
# installed, the shell pops up a notice naming it, instead of the key doing nothing.

log="$HOME/script/misc/launch.log"

# Only stderr is read, a line at a time, so a long-running app is not held up or cut off.
sh -c "$1" 2>&1 >/dev/null | while IFS= read -r line; do
    # Only bash, dash and zsh's own forms, so an app's "x: not found" warning is not taken for one.
    if [[ $line =~ :\ ([^:\ ]+):\ command\ not\ found$ || $line =~ ^[^:]+:\ [0-9]+:\ ([^:\ ]+):\ not\ found$ || $line =~ command\ not\ found:\ ([^:\ ]+)$ ]]; then
        missing=${BASH_REMATCH[1]}
    else
        continue
    fi

    echo "<ERROR> $(date +"%Y-%m-%d %H:%M:%S"): $missing not found, running: $1" >> "$log"
    # In the background: the notice waits for a click, and the app must keep writing meanwhile.
    (
        action=$(notify-send -a UmmItOS -u critical -A packages="Open Packages" \
            "$missing is not installed" \
            "The shortcut needs it. Install the package that provides $missing, or see what UmmItOS is missing in Settings → Packages.")
        [[ "$action" == packages ]] && qs -c ummitos ipc call settings page 1
    ) &
done
