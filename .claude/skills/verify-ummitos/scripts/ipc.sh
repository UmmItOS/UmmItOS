#!/usr/bin/env bash
# ipc.sh <target> <function> [args...]: call the test shell's IPC (never the live one).
source "$(dirname "$0")/env.sh"
[[ ${1:-} == lock && ${2:-} == alarm ]] && { echo "refused: lock alarm opens a webcam and records a clip" >&2; exit 2; }
in_stack qs -c "$CONFIG_ID" ipc call "$@"
