#!/usr/bin/env bash
# Run by the lock screen on the second wrong password: a webcam clip of
# whoever is at the keyboard, kept only on this machine, and a frame file the
# lock screen shows live. The lock screen plays the alarm itself, on a loop.
# Style: https://style.ysap.sh/

state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
dir=$state/intruders
live=${XDG_RUNTIME_DIR:-/tmp}/ummitos-intruder-live
camera=${UMMITOS_CAMERA:-/dev/video0}
seconds=30

# A preview of the alarm keeps its clip in memory only, and the lock deletes it on close.
[[ $1 == --preview ]] && dir=${XDG_RUNTIME_DIR:-/tmp}/ummitos-intruder-preview

mkdir -p "$dir" "$live" && chmod 700 "$dir" "$live"
clip=$dir/$(date +%Y-%m-%d_%H-%M-%S).mkv
frame=$live/frame.jpg
rm -f "$frame"

# The lock screen reads this path, then reloads the frame while it records.
echo "$frame"

# -t before -i limits the camera itself, so both outputs end; exec, so stopping the lock stops the camera.
umask 077
exec ffmpeg -loglevel error -t "$seconds" -f v4l2 -i "$camera" \
	-map 0:v -c:v libx264 -preset ultrafast -crf 28 -y "$clip" \
	-map 0:v -vf fps=8 -q:v 4 -update 1 -atomic_writing 1 -y "$frame" < /dev/null
