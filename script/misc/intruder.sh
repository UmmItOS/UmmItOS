#!/usr/bin/env bash
# Run by the lock screen on the second wrong password: picks where the webcam
# clip of whoever is at the keyboard goes, in a folder only you can read. The
# lock screen records it and shows the camera live, and plays the alarm itself.
# Style: https://style.ysap.sh/

dir=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos/intruders

# A preview of the alarm keeps its clip in memory only, and the lock deletes it on close.
[[ $1 == --preview ]] && dir=${XDG_RUNTIME_DIR:-/tmp}/ummitos-intruder-preview

mkdir -p "$dir" && chmod 700 "$dir" && echo "$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
