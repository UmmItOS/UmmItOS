#!/usr/bin/env bash
# shellcheck disable=SC1091

# Frame rate
FPS=185

# Directory where wallpapers are stored
WALLPAPER_DIR="$HOME/.wallpaper"

# Change the variable below to 0 if you don't want to change the wallpaper
# its for hyprlock wallpaper
same_wallpaper=1

# Get list of all files (including those in subdirectories) in the wallpaper directory
# and filter out only the files with jpg, png, and jpeg extensions
filenames=$(find "$WALLPAPER_DIR" -type f -regex '.*\.\(jpg\|png\|jpeg\)' -printf "%P\n")

# Check if rofi is already running
if pgrep -x "rofi" > /dev/null; then
    hyprctl notify 3 2500 "rgb(C62E2E)" "fontsize:35   Bruh, Don't launch multiple instances of rofi 🫠"
    echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Bruh, Don't launch multiple instances of rofi 🫠 - awww" >> ~/script/awww/awww.log
    exit 1
fi

# Build entries differently
entries=""
while IFS= read -r filename; do
    [[ -n "$filename" ]] && entries+="${filename}\x00icon\x1f${WALLPAPER_DIR}/${filename}\n"
done <<< "$filenames"

# Remove the last newline character before passing to rofi
entries=${entries%\\n}
selected=$(printf "%b" "$entries" | rofi -dmenu -p "Wallpaper Picker" -theme ~/.config/rofi/wallpaper-picker.rasi)

# Check if user selected a wallpaper
if [[ -n "$selected" ]]; then
    selected=${selected%%$'\x00icon\x1f'*}

    selected_path="$WALLPAPER_DIR/$selected"

    # Get the filename from the selected path
    selected_filename=$(basename "$selected")

    # Randomly choose a transition type and its arguments
    transition_options=(
        "--transition-type random --transition-pos 0.977,0.969 --transition-step 90 --transition-duration 2.5"
        "--transition-type center --transition-pos 0.977,0.969 --transition-step 90 --transition-duration 2.5"
    )

    # Choose a random index
    selected_transition=${transition_options[RANDOM % ${#transition_options[@]}]}
    read -ra transition_args <<< "$selected_transition"

    # Wallpaper picker with awww using the selected transition
    awww img \
        --transition-fps "$FPS" \
        "${transition_args[@]}" \
        "$selected_path"

    if (( same_wallpaper == 1 )); then
        source "$HOME"/script/awww/detect.sh
    fi

    hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   Ayo, Wallpaper changed to $selected_filename 🚀"
    echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Wallpaper changed to $selected_filename - awww" >> ~/script/awww/awww.log

else
    hyprctl notify 2 2500 "rgb(FEEC37)" "fontsize:35   Don't you choose wallpaper? 🤔"
    echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Don't you choose wallpaper? 🤔 - awww" >> ~/script/awww/awww.log
fi
