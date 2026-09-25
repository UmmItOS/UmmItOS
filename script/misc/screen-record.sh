#!/usr/bin/env bash
# Super+Shift+R: stop the recording, or open the shell's recording dialog.
# The dialog runs `screen-record.sh start <system 0|1> <mic 0|1>` after its countdown.

dir="$HOME/Videos/Recordings"
log="$HOME/script/misc/screen-record.log"
state="${XDG_RUNTIME_DIR:-/tmp}/screen-record"

# Undo the temporary mix sink, if this recording made one.
unmix() {
    if [[ -f "$state/modules" ]]; then
        while read -r id; do pactl unload-module "$id"; done < "$state/modules"
        rm -f "$state/modules"
    fi
}

# A broken mic sends one stuck full-scale value, which drowns everything mixed with it;
# one that cannot be read at all counts as dead too.
mic_dead() {
    local mean
    mean=$(ffmpeg -hide_banner -f pulse -i "$1" -t 0.5 -af volumedetect -f null - 2>&1 | sed -n 's/.*mean_volume: \(-\?[0-9.]*\) dB/\1/p')
    [[ -z "$mean" ]] || awk -v m="$mean" 'BEGIN { exit !(m > -3) }'
}

if pid=$(pgrep -x wl-screenrec); then
    kill -INT "$pid"
    # The file is only complete once the recorder has exited.
    while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    file=$(cat "$state/path" 2>/dev/null)
    note=$(cat "$state/note" 2>/dev/null)
    rm -f "$state/path" "$state/note"
    unmix
    notify-send -a "Screen recording" "Recording saved" "$file${note:+
$note}"
    echo "$(date '+%F %T') saved $file" >> "$log"
    exit 0
fi

if [[ "$1" != start ]]; then
    exec qs -c ummitos ipc call record open
fi

system=$2
mic=$3
mkdir -p "$dir" "$state"
file="$dir/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
echo "$file" > "$state/path"

# Said when saving, not now: a notice now would be in the video.
if [[ "$mic" == 1 ]] && mic_dead "$(pactl get-default-source)"; then
    mic=0
    if [[ "$system" == 1 ]]; then
        echo "The microphone gave no sound, so only system sound was recorded." > "$state/note"
    else
        echo "The microphone gave no sound, so the video is silent." > "$state/note"
    fi
fi

# wl-screenrec takes one audio device, so both are mixed into a temporary sink.
audio=()
if [[ "$system" == 1 && "$mic" == 1 ]]; then
    {
        pactl load-module module-null-sink sink_name=ummitos-record sink_properties=device.description=Recording
        pactl load-module module-loopback source="$(pactl get-default-sink).monitor" sink=ummitos-record
        pactl load-module module-loopback source="$(pactl get-default-source)" sink=ummitos-record
    } > "$state/modules"
    audio=(--audio --audio-device ummitos-record.monitor)
elif [[ "$system" == 1 ]]; then
    audio=(--audio --audio-device "$(pactl get-default-sink).monitor")
elif [[ "$mic" == 1 ]]; then
    audio=(--audio --audio-device "$(pactl get-default-source)")
fi

echo "$(date '+%F %T') started $file on $output (system=$system mic=$mic)" >> "$log"

# --low-power=off: AMD has no low-power H.264 encoder, so the first try always failed.
if ! wl-screenrec "${audio[@]}" --low-power=off -o "$output" -f "$file" 2>> "$log"; then
    rm -f "$state/path"
    unmix
    notify-send -a "Screen recording" "Recording failed" "See $log"
fi
