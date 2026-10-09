#!/usr/bin/env bash

unit=ummitos-clipboard-expiry
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ummitos"
state_file="$state_dir/clipboard-expiry"
self=$(readlink -f "$0")

cancel_unit() {
    systemctl --user stop "$unit.timer" "$unit.service" &> /dev/null || true
    systemctl --user reset-failed "$unit.timer" "$unit.service" &> /dev/null || true
}

arm() {
    local deadline=$1
    cancel_unit
    systemd-run --user --quiet --collect --unit="$unit" \
        --on-calendar="@$deadline" --timer-property=AccuracySec=1s \
        --timer-property=Persistent=true "$self" expire "$deadline"
}

case "${1:-}" in
    schedule)
        minutes="${2:-0}"
        [[ "$minutes" =~ ^[0-9]+$ ]] || exit 2
        cancel_unit
        if (( minutes == 0 )); then
            rm -f -- "$state_file"
            exit 0
        fi
        deadline=$(( $(date +%s) + minutes * 60 ))
        mkdir -p "$state_dir"
        temporary="$state_file.$$"
        printf '%s\n' "$deadline" > "$temporary"
        mv -f -- "$temporary" "$state_file"
        arm "$deadline"
        ;;
    enforce)
        [[ -f "$state_file" ]] || exit 0
        read -r deadline < "$state_file"
        if [[ ! "$deadline" =~ ^[0-9]+$ ]]; then
            rm -f -- "$state_file"
            exit 1
        fi
        if (( $(date +%s) >= deadline )); then
            "$self" expire "$deadline"
        else
            arm "$deadline"
        fi
        ;;
    expire)
        expected="${2:-}"
        [[ "$expected" =~ ^[0-9]+$ && -f "$state_file" ]] || exit 0
        read -r current < "$state_file"
        [[ "$current" = "$expected" ]] || exit 0
        if cliphist wipe; then
            rm -f -- "$state_file"
            wl-copy --clear
            notify-send -a Clipboard -- "Clipboard cleared" "Copied items expired and were removed." 2> /dev/null || true
        fi
        ;;
    cancel)
        cancel_unit
        rm -f -- "$state_file"
        ;;
    clear)
        cancel_unit
        rm -f -- "$state_file"
        cliphist wipe && wl-copy --clear
        ;;
    *)
        echo "Usage: $0 {schedule MINUTES|enforce|expire DEADLINE|cancel|clear}" >&2
        exit 2
        ;;
esac
