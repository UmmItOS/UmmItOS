#!/usr/bin/env bash
# Run by the lock screen on the second wrong password: one webcam photo of
# whoever is at the keyboard, kept only on this machine, and a quiet intruder
# alarm that follows the output's mute, so a muted laptop in class stays silent.
# Style: https://style.ysap.sh/

state=${XDG_STATE_HOME:-$HOME/.local/state}/ummitos
dir=$state/intruders
sound=${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/sounds/intruder
camera=${UMMITOS_CAMERA:-/dev/video0}

mkdir -p "$dir" && chmod 700 "$state" "$dir"

# The first frames come out dark while the camera sets its exposure.
photo() {
	local file
	file=$dir/$(date +%Y-%m-%d_%H-%M-%S).jpg
	ffmpeg -loglevel error -f v4l2 -i "$camera" -vf "select=gte(n\,15)" \
		-frames:v 1 -y "$file" < /dev/null && chmod 600 "$file"
}

photo &
pw-play "$sound"
wait
