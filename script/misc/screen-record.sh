#!/usr/bin/env bash
# Super+Shift+R: stop the recording, or open the shell's recording dialog.
# The dialog runs `screen-record.sh start <system 0|1> <mic 0|1>` after its countdown.

# The settings panel (Settings.qml) writes these; missing keys keep the defaults.
folder="$HOME/Videos/Recordings"
quality=ultra
fps=0
codec=hevc
cursor=1
conf="${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/recording.conf"
if [[ -f "$conf" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            folder | quality | fps | codec | cursor) [[ -n "$value" ]] && printf -v "$key" '%s' "$value" ;;
        esac
    done < "$conf"
fi
# avc is wl-screenrec's name for H.264, in files saved before the switch.
[[ "$codec" == avc ]] && codec=h264
dir="$folder"
log="$HOME/script/misc/screen-record.log"
state="${XDG_RUNTIME_DIR:?not in a session}/screen-record"

# By pid, not name: the kernel cuts gpu-screen-recorder's name to 15 characters.
pid=$(cat "$state/pid" 2>/dev/null)
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    asked=${EPOCHREALTIME/./}
    kill -INT "$pid"
    # The file is only complete once the recorder has exited.
    while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
    file=$(cat "$state/path" 2>/dev/null)
    note=$(cat "$state/note" 2>/dev/null)
    rm -f "$state/path" "$state/note" "$state/pid"
    qs -c ummitos ipc call record stopped
    notify-send -a "Screen recording" "Recording saved" "$file${note:+
$note}"
    # How long the recorder took to finish the file, to catch a slow stop.
    echo "$(date '+%F %T') saved $file (stop took $(( (${EPOCHREALTIME/./} - asked) / 1000 )) ms)" >> "$log"
    exit 0
fi

if [[ "$1" != start ]]; then
    qs -c ummitos ipc call record idle
    exec qs -c ummitos ipc call record open
fi

system=$2
mic=$3
mkdir -p "$dir" "$state"
# A note left by a recording that failed must not reach this one.
rm -f "$state/note"
file="$dir/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
read -r output rate < <(hyprctl -j monitors | jq -r '.[] | select(.focused) | "\(.name) \(.refreshRate | round)"')
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

audio=()
if [[ "$system" == 1 && "$mic" == 1 ]]; then
    audio=(-a "default_output|default_input")
elif [[ "$system" == 1 ]]; then
    audio=(-a default_output)
elif [[ "$mic" == 1 ]]; then
    audio=(-a default_input)
fi

echo "$(date '+%F %T') started $file on $output (system=$system mic=$mic)" >> "$log"
# The bar shows a recording pill while this runs; nothing else on screen says so.
qs -c ummitos ipc call record started

# 0 is the screen's own refresh rate. Full colour range keeps blacks black instead of grey.
[[ "$fps" == 0 ]] && fps=$rate
[[ "$cursor" == 0 ]] && cursor=no || cursor=yes

gpu-screen-recorder -w "$output" -f "$fps" -k "$codec" -q "$quality" -cr full -cursor "$cursor" "${audio[@]}" -o "$file" > /dev/null 2>> "$log" &
echo $! > "$state/pid"
if ! wait $!; then
    rm -f "$state/path" "$state/note" "$state/pid"
    qs -c ummitos ipc call record stopped
    notify-send -a "Screen recording" "Recording failed" "See $log"
fi
