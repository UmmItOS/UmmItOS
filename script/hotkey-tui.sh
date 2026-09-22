#!/usr/bin/env bash
# Keybind cheatsheet, read from the running Hyprland session.
# Only binds with a description (bindd, bindeld, ...) in configs/hypr are listed,
# so the table can't drift from the real config.

rows=$(hyprctl binds -j 2>/dev/null | jq -r '
    {"36": "Enter"} as $codes
    | {"mouse:272": "Left drag", "mouse:273": "Right drag",
       "mouse_down": "Scroll down", "mouse_up": "Scroll up"} as $names
    | .[] | select(.has_description) | .modmask as $m | .description as $d
    | ([[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
        | map(select(($m / .[0] | floor) % 2 == 1) | .[1]))
      + [if .keycode != 0 then ($codes[.keycode | tostring] // "code:\(.keycode)")
         else ($names[.key] // .key) end]
    | join(" + ") + "\t" + $d' 2>/dev/null | column -t -s $'\t')

if [[ -z $rows ]]; then
    echo "No described keybinds found. Is Hyprland running with the UmmItOS config?"
    read -rp "Press Enter to close..."
    exit 1
fi

if command -v fzf &>/dev/null; then
    fzf --no-sort --reverse --prompt "Keybinds > " --header "Type to filter, Esc to close" <<< "$rows"
else
    less <<< "$rows"
fi
