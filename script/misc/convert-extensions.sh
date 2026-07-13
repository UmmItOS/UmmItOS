#!/usr/bin/env bash

# this file still testing, for convert all files into specific extension (jpg, jpeg, png)

target_dir="$HOME/.wallpaper/"

mapfile -t non_image_files < <(find "$target_dir" -type f ! \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))

if [[ ${#non_image_files[@]} -gt 0 ]]; then
    echo "Found non-image files:"
    printf '%s\n' "${non_image_files[@]}"
else
    echo "No non-image files found."
fi
