pragma Singleton

import Quickshell
import Quickshell.Io
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
        onTriggered: {
            const file = root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
            const target = root.pendingGeometry !== "" ? ["-g", root.pendingGeometry] : ["-o", root.pendingOutput];
            shot.command = ["sh", "-c", 'mkdir -p "$1" && f="$2" && shift 2 && grim "$@" "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"', "sh", root.dir, file, ...target];
            shot.running = true;
        }
    }

    Process {
        id: shot
    }

    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            root.open = !root.open;
        }
    }
}
