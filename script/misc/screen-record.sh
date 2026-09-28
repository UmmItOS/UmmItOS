#!/usr/bin/env bash
# Super+Shift+R: stop the recording, or open the shell's recording dialog.
# The dialog runs `screen-record.sh start <system 0|1> <mic 0|1>` after its countdown.

# The settings panel (Settings.qml) writes these; missing keys keep the defaults.
folder="$HOME/Videos/Recordings"
bitrate="5 MB"
fps=60
codec=auto
cursor=1
conf="${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/recording.conf"
if [[ -f "$conf" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            folder | bitrate | fps | codec | cursor) [[ -n "$value" ]] && printf -v "$key" '%s' "$value" ;;
        esac
    done < "$conf"
fi
dir="$folder"
log="$HOME/script/misc/screen-record.log"
state="${XDG_RUNTIME_DIR:-/tmp}/screen-record"

# Undo the temporary mix sink, if this recording made one.
unmix() {
    if [[ -f "$state/modules" ]]; then
        while read -r id; do pactl unload-module "$id"; done < "$state/modules"
        rm -f "$state/modules"
    fi
}

if pid=$(pgrep -x wl-screenrec); then
    kill -INT "$pid"
    # The file is only complete once the recorder has exited.
    while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    file=$(cat "$state/path" 2>/dev/null)
    note=$(cat "$state/note" 2>/dev/null)
    rm -f "$state/path" "$state/note"
    unmix
    qs -c ummitos ipc call record stopped
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
# A note left by a recording that failed must not reach this one.
rm -f "$state/note"
file="$dir/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
echo "$file" > "$state/path"

# Said when saving, not now: a notice now would be in the video.
# A broken mic's stuck signal would drown everything mixed with it.
if [[ "$mic" == 1 ]] && ! "$HOME/script/misc/mic-check.sh"; then
    mic=0
    if [[ "$system" == 1 ]]; then
        echo "The microphone is not working, so only system sound was recorded. Reboot to fix it." > "$state/note"
    else
        echo "The microphone is not working, so the video is silent. Reboot to fix it." > "$state/note"
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
# The bar shows a recording pill while this runs; nothing else on screen says so.
qs -c ummitos ipc call record started

# --low-power=off: AMD has no low-power H.264 encoder, so the first try always failed.
video=(-b "$bitrate" --codec "$codec")
[[ "$fps" != 0 ]] && video+=(-m "$fps")
[[ "$cursor" == 0 ]] && video+=(--no-cursor)

if ! wl-screenrec "${audio[@]}" "${video[@]}" --low-power=off -o "$output" -f "$file" 2>> "$log"; then
    rm -f "$state/path" "$state/note"
    unmix
    qs -c ummitos ipc call record stopped
    notify-send -a "Screen recording" "Recording failed" "See $log"
fi
