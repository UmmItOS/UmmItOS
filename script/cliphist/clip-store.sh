#!/usr/bin/env bash
# Run by `wl-paste --watch` on every copy: store it, and say so.
cliphist store
hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   New text copied ✨"
