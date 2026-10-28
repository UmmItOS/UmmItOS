#!/usr/bin/env bash
# Read-only: is the test stack worth driving? Exit 0 = yes.
source "$(dirname "$0")/env.sh"
ok=1
# check "<description>" <command...>: prints ok or FAIL.
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then printf 'ok   %s\n' "$d"; else printf 'FAIL %s\n' "$d"; ok=0; fi; }
[[ -f $STACK/stack.env ]] || { echo "FAIL no stack (run up.sh)"; exit 1; }
check "nested session alive" kill -0 "$(cat "$STACK/session.pid")"
check "test qs -c $CONFIG_ID alive" kill -0 "$(cat "$STACK/qs.pid")"
check "nested Hyprland $NESTED_SIG answers" in_stack hyprctl -j monitors
check "shell under test is $REPO/configs/quickshell" test "$(readlink "$STACK/home/.config/quickshell/$CONFIG_ID")" = "$REPO/configs/quickshell"
frames_ok() { in_stack hyprctl -j monitors | grep -q '"VERIFY"'; }
check "headless output VERIFY renders" frames_ok
hypr_ipc_ok() { [[ -S $STACK/run/hypr/$NESTED_SIG/.socket2.sock && -f $STACK/qs.out ]] && ! grep -qE 'ServerNotFound|Unable to find hyprland socket|Cannot connect to hyprland|Unable to connect to hyprland event socket|Hyprland ipc status request failed|event socket disconnected' "$STACK/qs.out"; }
check "test shell reaches Hyprland IPC (socket2)" hypr_ipc_ok
ipc_ok() { in_stack qs -c "$CONFIG_ID" ipc show | grep -q '^target lock'; }
check "IPC targets reachable" ipc_ok
# shellcheck disable=SC2016 # expanded by the inner sh
check "last load clean" sh -c 'grep -E "Configuration Loaded|ERROR" "$1" | tail -1 | grep -q "Configuration Loaded"' sh "$STACK/qs.out"
echo "evidence: $EVIDENCE"
(( ok ))
