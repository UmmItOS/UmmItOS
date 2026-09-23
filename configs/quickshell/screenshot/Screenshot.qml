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
    // "region" (drag), "window" (pick one) or "screen" (the whole monitor).
    // All three go through the same overlay, so they look and feel the same.
    property string mode: "region"
    // Windows on the focused monitor's workspace, most recently focused
    // first, in global coordinates: { x, y, w, h, title }.
    property var windows: []

    function start(newMode: string): void {
        mode = newMode;
        // Cleared first: a list left over from the last time would frame a
        // window from another layout until the fresh one arrives.
        if (newMode === "window") {
            windows = [];
            clients.running = true;
        }
        open = true;
    }

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
    // arguments.
    function take(target: var): void {
        const file = root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        shot.command = ["sh", "-c", 'mkdir -p "$1" && f="$2" && shift 2 && grim "$@" "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"', "sh", root.dir, file, ...target];
        shot.running = true;
    }

    Process {
        id: shot
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const ws = Hyprland.focusedMonitor?.activeWorkspace?.id;
                try {
                    root.windows = JSON.parse(text).filter(c => c.mapped && !c.hidden && c.workspace.id === ws).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => ({
                                x: c.at[0],
                                y: c.at[1],
                                w: c.size[0],
                                h: c.size[1],
                                title: c.title
                            }));
                } catch (e) {
                    root.windows = [];
                }
            }
        }
    }

    IpcHandler {
        target: "screenshot"

        function toggle(): void {
            if (root.open)
                root.open = false;
            else
                root.start("region");
        }

        function screen(): void {
            root.start("screen");
        }

        function window(): void {
            root.start("window");
        }
    }
}
