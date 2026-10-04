#!/usr/bin/env bash

set -euo pipefail

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export calls="$tmp/calls"
export types=text/plain
export XDG_STATE_HOME="$tmp/state"

cliphist() {
    printf 'cliphist %s\n' "$*" >> "$calls"
    if [[ "${1:-}" = store ]]; then
        command cat > /dev/null
    fi
    return 0
}

wl-paste() {
    printf 'wl-paste %s\n' "$*" >> "$calls"
    [[ "${1:-}" = --list-types ]] && printf '%s\n' "$types"
}

wl-copy() {
    printf 'wl-copy %s\n' "$*" >> "$calls"
}

qs() {
    printf 'qs %s\n' "$*" >> "$calls"
}

systemctl() {
    printf 'systemctl %s\n' "$*" >> "$calls"
}

systemd-run() {
    printf 'systemd-run %s\n' "$*" >> "$calls"
    return "${SYSTEMD_RUN_STATUS:-0}"
}

date() {
    case "${1:-}" in
        +%s) printf '1000\n' ;;
        -Is) printf '2026-10-05T00:00:00+00:00\n' ;;
        *) command date "$@" ;;
    esac
}

notify-send() {
    printf 'notify-send %s\n' "$*" >> "$calls"
}

export -f cliphist wl-paste wl-copy qs systemctl systemd-run date notify-send

run_store() {
    printf '' > "$calls"
    printf 'copied value' | XDG_CONFIG_HOME="$tmp/config" CLIPBOARD_STATE="$1" script/cliphist/clip-store.sh
}

mkdir -p "$tmp/config/ummitos"

run_store sensitive
[[ ! -s "$calls" ]]

printf 'history=0\nclear_minutes=0\n' > "$tmp/config/ummitos/privacy.conf"
run_store data
if grep -q '^cliphist store$' "$calls"; then
    exit 1
fi
grep -q '^qs .* copied text$' "$calls"

printf 'history=1\nclear_minutes=15\n' > "$tmp/config/ummitos/privacy.conf"
run_store data
grep -q '^cliphist store$' "$calls"
grep -q '^systemd-run .*--on-calendar=@1900 .*--timer-property=Persistent=true .* expire 1900$' "$calls"
[[ $(< "$tmp/state/ummitos/clipboard-expiry") = 1900 ]]

printf '' > "$calls"
script/cliphist/clipboard-expiry.sh enforce
grep -q '^systemd-run .*--on-calendar=@1900' "$calls"

printf '' > "$calls"
script/cliphist/clipboard-expiry.sh expire 1900
grep -q '^cliphist wipe$' "$calls"
[[ ! -e "$tmp/state/ummitos/clipboard-expiry" ]]

printf 'history=1\nclear_minutes=0\n' > "$tmp/config/ummitos/privacy.conf"
types=image/png run_store data
grep -q '^cliphist store$' "$calls"
grep -q '^qs .* copied image$' "$calls"

printf '' > "$calls"
script/cliphist/clipboard-expiry.sh clear
grep -q '^cliphist wipe$' "$calls"
grep -q '^wl-copy --clear$' "$calls"

printf 'clip-store tests passed\n'
