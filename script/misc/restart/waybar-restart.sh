#!/usr/bin/env bash

# Log path
log_file=~/script/waybar/waybar-restart.log

# Check if Waybar is running
if pgrep -x "waybar" > /dev/null; then
    killall waybar
    nohup waybar --log-level debug >> "$log_file" 2>&1 &
    hyprctl notify 1 2500 "rgb(ED5AB3)" "fontsize:35   Waybar has been restarted."
    echo "Waybar has been restarted."
else
    echo "Waybar is not currently running. will start it."
    nohup waybar --log-level debug >> "$log_file" 2>&1 &
    hyprctl notify 1 2500 "rgb(ED5AB3)" "fontsize:35   Waybar has been started."
    echo "Waybar has been started."
fi
