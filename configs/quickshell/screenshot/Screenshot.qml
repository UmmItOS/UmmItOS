pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import ".."

// Region screenshots. The window freezes the screen and draws the selection;
// this does the capture once the overlay is gone, so it is not in the shot.
Singleton {
    id: root

    property bool open: false

    readonly property string dir: Quickshell.env("HYPRSHOT_DIR") || Quickshell.env("HOME") + "/Pictures/Screenshots"

    // grim geometry ("x,y wxh") or an output name, waiting for the overlay
    // to leave the screen.
    property string pendingGeometry: ""
    property string pendingOutput: ""

    function region(geometry: string): void {
        pendingGeometry = geometry;
        pendingOutput = "";
        finish();
    }

    function output(name: string): void {
        pendingGeometry = "";
        pendingOutput = name;
        finish();
    }

    function finish(): void {
        open = false;
        settle.restart();
    }

    // Long enough for the exit animation, so the overlay is not captured.
    Timer {
        id: settle
        interval: Theme.duration.expressiveFastSpatial + Theme.duration.small
        onTriggered: root.take(root.pendingGeometry !== "" ? ["-g", root.pendingGeometry] : ["-o", root.pendingOutput])
    }

    // Saves, copies to the clipboard and says so. `target` is grim's own
    // arguments; "window" asks Hyprland for the active window's box.
    function take(target: var): void {
        const file = root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        shot.command = ["sh", "-c", 'mkdir -p "$1" && f="$2" && shift 2 && if [ "$1" = window ]; then set -- -g "$(hyprctl activewindow -j | jq -r \'"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\')"; fi && grim "$@" "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"', "sh", root.dir, file, ...target];
        shot.running = true;
    }

    Process {
        id: shot
    }

    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            root.open = !root.open;
        }

        // The whole focused monitor, straight away.
        function screen(): void {
            root.take(["-o", Hyprland.focusedMonitor?.name ?? ""]);
        }

        function window(): void {
            root.take(["window"]);
        }
    }
}
