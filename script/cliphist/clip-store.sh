#!/usr/bin/env bash
# Run by `wl-paste --watch` on every copy: store it, and say what was copied.
cliphist store
if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
    hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   Image copied 🖼️"
else
    hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   New text copied ✨"
fi
