#!/usr/bin/env bash
# Start an isolated test stack: nested Hyprland (hidden on special:verify) + private D-Bus +
# private XDG_RUNTIME_DIR + fake HOME, with qs -c ummitos-test running the repo's shell.
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ -f $STACK/stack.env ]]; then echo "A stack is already up ($STACK). Run down.sh first." >&2; exit 1; fi
if [[ -e $STACK && ! -f $MARKER ]]; then echo "$STACK exists but up.sh did not create it; refusing to start." >&2; exit 1; fi
mkdir -p "$STACK" && chmod 700 "$STACK" && touch "$MARKER"
mkdir -p "$STACK/run" "$STACK/home/.config/quickshell" && chmod 700 "$STACK/run"
RUN_ID=$(date +%Y%m%d-%H%M%S)
EVIDENCE=$EVIDENCE_ROOT/$RUN_ID; mkdir -p "$EVIDENCE"
# The shell under test, by its own config id, inside the fake HOME only.
ln -sfn "$REPO/configs/quickshell" "$STACK/home/.config/quickshell/$CONFIG_ID"
# Hyprland config copy: no autostart (it would start a second qs), a fixed monitor mode.
cp -r "$REPO/configs/hypr" "$STACK/hypr"
# Also no permissions module: its screencopy prompt would block the shell's own captures in the test.
sed -i '/require("hyprland.autostart")/d; /require("hyprland.permissions")/d; 0,/^hl\.monitor(/s|^hl\.monitor(.*|hl.monitor({ output = "", mode = "1920x1080@60", position = "auto", scale = 1 })|' "$STACK/hypr/hyprland.lua"
# Keep the nested window off the user's screen (runtime rule in the parent Hyprland, removed by down.sh).
hyprctl eval 'hl.window_rule({ name = "verify-ummitos-nested", match = { class = "^aquamarine$" }, workspace = "special:verify silent" })' >/dev/null
# shellcheck disable=SC2016 # the inner sh expands these
env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" HOME="$STACK/home" USER="$USER" XDG_RUNTIME_DIR="$STACK/run" \
    WAYLAND_DISPLAY="$PARENT_RUNTIME/${WAYLAND_DISPLAY:-wayland-1}" XDG_DATA_DIRS=/usr/local/share:/usr/share \
    setsid dbus-run-session -- sh -c 'echo "$DBUS_SESSION_BUS_ADDRESS" > "$1/bus"; exec start-hyprland -- -c "$1/hypr/hyprland.lua"' sh "$STACK" \
    > "$STACK/hyprland.log" 2>&1 &
echo $! > "$STACK/session.pid"
# Ready 1: the nested compositor answers on its own socket.
for _ in $(seq 100); do
    sig=""; for d in "$STACK"/run/hypr/*/; do [[ -d $d ]] && sig=$(basename "$d"); done
    if [[ -n $sig ]]; then
        sock=$STACK/run/hypr/$sig/.socket2.sock; len=$(printf %s "$sock" | wc -c)
        # sun_path holds 107 bytes plus NUL; a longer path silently disables Hyprland IPC for the shell.
        if ((len >= 108)); then echo "Hyprland socket path is $len bytes (max 107): $sock" >&2; "$(dirname "$0")/down.sh" >&2; exit 1; fi
    fi
    if [[ -n $sig ]] && XDG_RUNTIME_DIR="$STACK/run" HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl -j monitors >/dev/null 2>&1; then break; fi
    sleep 0.1
done
[[ -n ${sig:-} ]] || { echo "Nested Hyprland did not start; see $STACK/hyprland.log" >&2; exit 1; }
wl=""; for w in "$STACK"/run/wayland-[0-9]*; do [[ -S $w ]] && wl=$(basename "$w"); done
cat > "$STACK/stack.env" <<ENV
RUN_ID=$RUN_ID
EVIDENCE=$EVIDENCE
NESTED_SIG=$sig
NESTED_WAYLAND=$wl
NESTED_BUS=$(cat "$STACK/bus")
ENV
# shellcheck disable=SC1091 # just written above
source "$STACK/stack.env"
# A hidden window gets no frame callbacks, so grim on it waits forever. Render on a headless output
# (its own timer) and switch the window output off, so every surface lands on VERIFY.
in_stack hyprctl output create headless VERIFY >/dev/null
for _ in $(seq 50); do in_stack hyprctl -j monitors | grep -q '"VERIFY"' && break; sleep 0.1; done
in_stack hyprctl eval 'hl.monitor({ output = "VERIFY", mode = "1920x1080@60", position = "0x0", scale = 1 })' >/dev/null
in_stack hyprctl eval 'hl.monitor({ output = "WAYLAND-1", disabled = true })' >/dev/null
# Ready 2: the shell under test has loaded its configuration.
# Mask V4L2 nodes inside qs only: the lock's intruder alarm opens a Qt Camera, and /dev is the real one.
mask=(); for n in /dev/video* /dev/media*; do [[ -e $n ]] && mask+=(--ro-bind /dev/null "$n"); done
# The inner sh records its own pid, then becomes the process-group leader (setsid) that down.sh kills; $! would be in_stack's subshell.
# shellcheck disable=SC2016 # the inner sh expands these
in_stack sh -c 'echo $$ > "$1/qs.pid"; shift; exec setsid "$@"' sh "$STACK" bwrap --dev-bind / / "${mask[@]}" qs -c "$CONFIG_ID" > "$STACK/qs.out" 2>&1 &
for _ in $(seq 150); do
    grep -q 'Configuration Loaded' "$STACK/qs.out" 2>/dev/null && break
    sleep 0.2
done
grep -q 'Configuration Loaded' "$STACK/qs.out" || { echo "qs did not load; see $STACK/qs.out" >&2; exit 1; }
echo "up: run $RUN_ID, evidence in $EVIDENCE"
