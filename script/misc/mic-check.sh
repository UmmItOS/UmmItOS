#!/usr/bin/env bash
# Exits 1 if the microphone is broken: unreadable, or stuck sending one full-scale value.
# The built-in mic (AMD acp63) gets stuck after some sleeps; a reboot brings it back.

source="${1:-$(pactl get-default-source)}"
mean=$(ffmpeg -hide_banner -f pulse -i "$source" -t 0.5 -af volumedetect -f null - 2>&1 | sed -n 's/.*mean_volume: \(-\?[0-9.]*\) dB/\1/p')
[[ -n "$mean" ]] && awk -v m="$mean" 'BEGIN { exit !(m <= -3) }'
