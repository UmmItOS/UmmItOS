#!/usr/bin/env bash
# Tear down only what up.sh started. Evidence in $EVIDENCE_ROOT is kept.
source "$(dirname "$0")/env.sh"
[[ -d $STACK ]] || { echo "no stack"; exit 0; }
[[ -f $STACK/qs.out ]] && [[ -n ${EVIDENCE:-} ]] && cp "$STACK/qs.out" "$EVIDENCE/qs.log" 2>/dev/null
for f in qs.pid session.pid; do
    pid=$(cat "$STACK/$f" 2>/dev/null) || continue
    # setsid made each one a process-group leader: signal the group (only what we started).
    kill -- -"$pid" 2>/dev/null; for _ in $(seq 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -9 -- -"$pid" 2>/dev/null
done
# D-Bus activation on the private bus can start helpers (gvfsd, xdg-document-portal) outside our
# process groups. They carry our private runtime dir in their environment, which only this stack uses.
for p in /proc/[0-9]*; do
    [[ -O $p ]] || continue
    if tr '\0' '\n' 2>/dev/null < "$p/environ" | grep -qx "XDG_RUNTIME_DIR=$STACK/run"; then kill "${p#/proc/}" 2>/dev/null; fi
done
sleep 0.5
# Their FUSE mounts live under the private runtime dir; unmount before deleting.
while read -r mnt; do fusermount3 -u "$mnt" 2>/dev/null || fusermount3 -uz "$mnt" 2>/dev/null; done < <(awk -v s="$STACK/" 'index($5, s) == 1 {print $5}' /proc/self/mountinfo)
# Remove the parent's hide rule and the scratch stack.
hyprctl eval 'hl.window_rule({ name = "verify-ummitos-nested", enabled = false })' >/dev/null 2>&1
rm -rf "$STACK"
echo "down; evidence kept in ${EVIDENCE:-$EVIDENCE_ROOT}"
