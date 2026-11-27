#!/usr/bin/env bash
# Stop processes this stack started, by process name and the stack's private runtime dir.
# Never match a command line instead: the caller's own shell can contain the same text and be killed with it.
source "$(dirname "$0")/env.sh"
[[ $# -ge 1 && $# -le 2 ]] || { echo "usage: stop.sh <name as in /proc/PID/comm> [signal, default TERM]" >&2; exit 2; }
[[ -f $MARKER ]] || { echo "no stack" >&2; exit 1; }
n=0
for p in /proc/[0-9]*; do
    [[ -O $p ]] || continue
    [[ $(cat "$p/comm" 2>/dev/null) == "$1" ]] || continue
    tr '\0' '\n' 2>/dev/null < "$p/environ" | grep -qx "XDG_RUNTIME_DIR=$STACK/run" || continue
    kill -s "${2:-TERM}" "${p#/proc/}" 2>/dev/null && n=$((n + 1))
done
echo "stopped $n $1"
