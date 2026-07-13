#!/usr/bin/env bash

# Log path
log_file=~/script/swaync/swaync-restart.log

# Check if Swaync is running
if pgrep -x "swaync" > /dev/null; then
    killall swaync
    nohup swaync >> "$log_file" 2>&1 &
    nohup swaync-client >> "$log_file" 2>&1 &
    hyprctl notify 1 2500 "rgb(ED5AB3)" "fontsize:35   Swaync has been restarted."
else
    echo "Swaync is not currently running. will start it."
    hyprctl notify 1 2500 "rgb(ED5AB3)" "fontsize:35   Swaync has been started."
    nohup swaync >> "$log_file" 2>&1 &
    echo "Swaync has been started."
fi
