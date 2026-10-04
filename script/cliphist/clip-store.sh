#!/usr/bin/env bash
# Run by `wl-paste --watch` on every copy: store it, and have the shell say
# what was copied.

# Check before cliphist reads stdin: password-manager entries must never reach disk.
[ "${CLIPBOARD_STATE:-}" = data ] || exit 0

history=1
clear_minutes=0
config="${XDG_CONFIG_HOME:-$HOME/.config}/ummitos/privacy.conf"
if [[ -f "$config" ]]; then
    while IFS='=' read -r key value; do
        case "$key" in
            history) [[ "$value" = 0 ]] && history=0 ;;
            clear_minutes) [[ "$value" =~ ^[0-9]+$ ]] && clear_minutes=$value ;;
        esac
    done < "$config"
fi

is_image=0
if wl-paste --list-types 2>/dev/null | grep -q '^image/'; then
    is_image=1
fi

if (( history )); then
    if cliphist store; then
        if ! "$(dirname "$0")/clipboard-expiry.sh" schedule "$clear_minutes" && (( clear_minutes > 0 )); then
            state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ummitos"
            mkdir -p "$state_dir"
            printf '%s Clipboard expiry scheduling failed\n' "$(date -Is)" >> "$state_dir/clipboard.log"
            if command -v notify-send > /dev/null; then
                notify-send -a Clipboard -u critical "Clipboard expiry failed" "Copied items will not clear automatically."
            fi
        fi
    fi
fi

if (( is_image )); then
    qs -c ummitos ipc call copied image
else
    qs -c ummitos ipc call copied text
fi
