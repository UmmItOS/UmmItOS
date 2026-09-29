#!/usr/bin/env bash
# First Hyprland login: offer the optional tuning pass once, then never again.
# Launched at login by hypr/hyprland/autostart.lua.

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ummitos"
sentinel="$state_dir/first-run-done"

# Second stage: we are already inside a terminal, ask the user.
if [[ "$1" == "--prompt" ]]; then
    repo_path=""
    [[ -f "$state_dir/repo-path" ]] && repo_path=$(<"$state_dir/repo-path")

    if [[ -z "$repo_path" || ! -x "$repo_path/post-install.sh" ]]; then
        echo "Welcome to UmmItOS. Your desktop is ready to use."
        echo "Optional tuning lives in post-install.sh inside the UmmItOS repo:"
        echo "  ./post-install.sh --start-config"
        read -rp "Press Enter to close..."
        exit 0
    fi

    echo "Welcome to UmmItOS. Your desktop is ready to use."
    echo ""
    echo "You can tune it further if you want to: lock the exact monitor mode, pick a"

    echo ""
    read -rp "Run the optional tuning now? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        exec "$repo_path/post-install.sh" --start-config
    fi
    echo "You can run it any time with: $repo_path/post-install.sh --start-config"
    read -rp "Press Enter to close..."
    exit 0
fi

# First stage: run once per user only.
[[ -f "$sentinel" ]] && exit 0
mkdir -p "$state_dir"
# Marked before prompting: a cancelled prompt must not nag on every login.
touch "$sentinel"

exec kitty -e "$0" --prompt
