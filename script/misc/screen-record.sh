#!/usr/bin/env bash
# Super+Shift+R: start a screen recording with wl-screenrec, or stop the one running.

dir="$HOME/Videos/Recordings"
log="$HOME/script/misc/screen-record.log"
state="${XDG_RUNTIME_DIR:-/tmp}/screen-record.path"

if pid=$(pgrep -x wl-screenrec); then
    kill -INT "$pid"
    # The file is only complete once the recorder has exited.
    while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    file=$(cat "$state" 2>/dev/null)
    rm -f "$state"
    notify-send -a "Screen recording" "Recording saved" "$file"
    echo "$(date '+%F %T') saved $file" >> "$log"
    exit 0
fi

mkdir -p "$dir"
file="$dir/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
echo "$file" > "$state"
notify-send -a "Screen recording" "Recording started" "Press Super+Shift+R again to stop."
echo "$(date '+%F %T') started $file on $output" >> "$log"

# The speakers' monitor, i.e. what the machine plays; plain --audio records the microphone.
sound="$(pactl get-default-sink).monitor"
# --low-power=off: AMD has no low-power H.264 encoder, so the first try always failed.
if ! wl-screenrec --audio --audio-device "$sound" --low-power=off -o "$output" -f "$file" 2>> "$log"; then
    rm -f "$state"
    notify-send -a "Screen recording" "Recording failed" "See $log"
fi
