#!/usr/bin/env bash

if ! pgrep -x "rofi" > /dev/null && ! ps -p "$PPID" -o comm= | grep -q "rofi"; then
    cliphist store
    hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   New text copied ✨"
fi
