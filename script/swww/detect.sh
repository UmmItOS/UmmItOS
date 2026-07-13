#!/usr/bin/env bash

WALLPAPER_PATH=$(swww query | grep -oP '(?<=currently displaying: image: ).*')

WALLPAPER_PATH_WITH_HOME=${WALLPAPER_PATH/#$HOME/\$HOME}

# Update only the background section's path in hyprlock.conf
sed -i '/^# Background wallpaper/,/^}/ s|^    path = .*|    path = '"$WALLPAPER_PATH_WITH_HOME"'|' "$HOME/.config/hypr/hyprlock.conf"

# Print the result to verify - used for debugging
echo "Updated hyprlock.conf background section with wallpaper path:"
echo "path = $WALLPAPER_PATH_WITH_HOME"