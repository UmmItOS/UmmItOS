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
# and filter out only the files with jpg, png, jpeg, and webp extensions
filenames=$(find "$WALLPAPER_DIR" -type f -regex '.*\.\(jpg\|png\|jpeg\)' -printf "%P\n")

# Check if wallpaper directory exists and contains files
if [[ ! -d "$WALLPAPER_DIR" ]]; then
    hyprctl notify 3 2500 "rgb(C62E2E)" "fontsize:35   Wallpaper directory not found! 😵"
    echo "<ERROR> $(date +"%Y-%m-%d %H:%M:%S"): Wallpaper directory not found - Random Wallpaper" >> ~/script/awww/awww.log
    exit 1
fi

# Convert filenames to array
wallpapers_array=()
while IFS= read -r filename; do
    [[ -n "$filename" ]] && wallpapers_array+=("$filename")
done <<< "$filenames"

# Check if any wallpapers found
if [[ ${#wallpapers_array[@]} -eq 0 ]]; then
    hyprctl notify 3 2500 "rgb(C62E2E)" "fontsize:35   No wallpapers found! 😵"
    echo "<ERROR> $(date +"%Y-%m-%d %H:%M:%S"): No wallpapers found - Random Wallpaper" >> ~/script/awww/awww.log
    exit 1
fi

# Randomly select a wallpaper
selected=${wallpapers_array[RANDOM % ${#wallpapers_array[@]}]}
selected_path="$WALLPAPER_DIR/$selected"

# Get the filename from the selected path
selected_filename=$(basename "$selected")

# Get the directory name from the selected path
selected_dir=$(dirname "$selected")
if [[ "$selected_dir" == "." ]]; then
    directory_name="root directory"
else
    directory_name=$(basename "$selected_dir")
fi

# Randomly choose a transition type and its arguments
transition_options=(
    "--transition-type random --transition-pos 0.977,0.969 --transition-step 90 --transition-duration 2.5"
    "--transition-type center --transition-pos 0.977,0.969 --transition-step 90 --transition-duration 2.5"
)

# Choose a random index
selected_transition=${transition_options[RANDOM % ${#transition_options[@]}]}
read -ra transition_args <<< "$selected_transition"

# Apply wallpaper with awww using the selected transition
awww img \
    --transition-fps "$FPS" \
    "${transition_args[@]}" \
    "$selected_path"

if (( same_wallpaper == 1 )); then
    if [[ -f "$HOME/script/awww/detect.sh" ]]; then
        source "$HOME"/script/awww/detect.sh
    fi
fi

hyprctl notify 5 2500 "rgb(86D293)" "fontsize:35   🖼️ Random wallpaper inside the <$directory_name> directory 🚀"
echo "<NOTICE> $(date +"%Y-%m-%d %H:%M:%S"): Random wallpaper changed to $selected_filename - Random Wallpaper" >> ~/script/awww/awww.log 
