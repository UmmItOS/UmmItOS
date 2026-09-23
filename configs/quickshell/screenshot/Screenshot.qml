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

    // True from a close until the overlay has fully left. A press in that
    // window used to reopen it mid-fade, half torn down, which flashed and
    // lost the effect; it is ignored instead.
    property bool leaving: false

    onOpenChanged: {
        if (!open) {
            leaving = true;
            left.restart();
        }
    }

    Timer {
        id: left
        interval: Theme.duration.expressiveFastSpatial + Theme.duration.small
        onTriggered: root.leaving = false
    }

    function start(newMode: string): void {
        if (leaving)
            return;
        mode = newMode;
        // Cleared first: a list left over from the last time would frame a
        // window from another layout until the fresh one arrives.
        if (newMode === "window") {
            windows = [];
            clients.running = true;
            makeDir.running = true;
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
    function newFile(): string {
        return root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
    }

    // A window shot is written by the shell itself (the window's own pixels,
    // transparency kept); this copies it and says so, as grim's path does.
    function saved(file: string): void {
        shot.command = ["sh", "-c", 'wl-copy --type image/png < "$1" && notify-send "Screenshot saved" "$1"', "sh", file];
        shot.running = true;
    }

    function take(target: var): void {
        const file = newFile();
        shot.command = ["sh", "-c", 'mkdir -p "$1" && f="$2" && shift 2 && grim "$@" "$f" && wl-copy --type image/png < "$f" && notify-send "Screenshot saved" "$f"', "sh", root.dir, file, ...target];
        shot.running = true;
    }

    Process {
        id: shot
    }

    // grabToImage cannot create the folder, so it is made up front.
    Process {
        id: makeDir
        command: ["mkdir", "-p", root.dir]
    }

    Process {
        id: clients
        // The active workspace and its windows in one go, from Hyprland
        // itself: read separately, the shell's idea of the workspace could
        // lag and name windows from another one. Tiny helper surfaces are
        // not windows anyone means to take.
        command: ["sh", "-c", 'ws=$(hyprctl activeworkspace -j | jq .id) && hyprctl clients -j | jq --argjson ws "$ws" \'[.[] | select(.workspace.id == $ws and .mapped and (.hidden | not) and .size[0] > 40 and .size[1] > 40)]\'']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text).sort((a, b) => a.focusHistoryID - b.focusHistoryID).map(c => ({
                                x: c.at[0],
                                y: c.at[1],
                                w: c.size[0],
                                h: c.size[1],
                                title: c.title,
                                address: c.address
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
