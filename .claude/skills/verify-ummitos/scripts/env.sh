# shellcheck shell=bash disable=SC2034
# Sourced by the other helpers. One test stack per user; its state lives here.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
PARENT_RUNTIME=${PARENT_RUNTIME:-/run/user/$(id -u)}
# Short on purpose: Hyprland's sockets live at $STACK/run/hypr/<62-char id>/.socket2.sock, and a Unix
# socket path over 108 bytes silently disables Hyprland IPC for the shell under test.
STACK=$PARENT_RUNTIME/vu
# up.sh writes this into $STACK it created; down.sh deletes nothing without it.
MARKER=$STACK/.verify-ummitos
EVIDENCE_ROOT=${XDG_STATE_HOME:-$HOME/.local/state}/verify-ummitos/runs
CONFIG_ID=ummitos-test
# Load what up.sh recorded, if a stack is running.
# shellcheck disable=SC1091 # written by up.sh at run time
[[ -f $STACK/stack.env ]] && source "$STACK/stack.env"
# Run a command inside the test stack (nested compositor, private bus, private runtime dir, fake HOME).
in_stack() {
    env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" HOME="$STACK/home" USER="$USER" \
        XDG_RUNTIME_DIR="$STACK/run" XDG_CONFIG_HOME="$STACK/home/.config" XDG_STATE_HOME="$STACK/home/.local/state" \
        XDG_CACHE_HOME="$STACK/home/.cache" XDG_DATA_DIRS="/usr/local/share:/usr/share" \
        WAYLAND_DISPLAY="$NESTED_WAYLAND" HYPRLAND_INSTANCE_SIGNATURE="$NESTED_SIG" \
        DBUS_SESSION_BUS_ADDRESS="$NESTED_BUS" QT_QPA_PLATFORM=wayland "$@"
}
