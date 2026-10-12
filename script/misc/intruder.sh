#!/usr/bin/env bash
# Run by the lock screen on the second wrong password: one webcam photo of
# whoever is at the keyboard, kept only on this machine. The lock screen plays
# the alarm itself, on a loop, so it can stop it the moment it is unlocked.
# Style: https://style.ysap.sh/

state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
dir=$state/intruders
camera=${UMMITOS_CAMERA:-/dev/video0}

# A preview of the alarm keeps its photo in memory only, and the lock deletes it on close.
[[ $1 == --preview ]] && dir=${XDG_RUNTIME_DIR:-/tmp}/ummitos-intruder-preview

mkdir -p "$dir" && chmod 700 "$dir"

# The first few frames come out dark while the camera sets its exposure.
# Prints the photo's path, which the lock screen shows back to them.
photo() {
	local file
	file=$dir/$(date +%Y-%m-%d_%H-%M-%S).jpg
	ffmpeg -loglevel error -f v4l2 -i "$camera" -vf "select=gte(n\,3)" \
		-frames:v 1 -y "$file" < /dev/null && chmod 600 "$file" && echo "$file"
}

photo
