pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Captures once the overlay is gone, so it is not in the shot.
Singleton {
    id: root

    property bool open: false
    property string mode: "region"
    // Global coordinates, most recently focused first.
    property var windows: []

    // A press mid-fade would reopen it half torn down.
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
        // Cleared first, or a stale window gets framed.
        if (newMode === "window") {
            windows = [];
            clients.running = true;
            makeDir.running = true;
        }
        open = true;
    }

    readonly property string dir: Quickshell.env("HYPRSHOT_DIR") || Quickshell.env("HOME") + "/Pictures/Screenshots"

    // grim geometry ("x,y wxh") or an output name.
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

    function newFile(): string {
        return root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
    }

    // A window shot is saved by the shell itself (keeps transparency).
    function saved(file: string): void {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1" && notify-send -a Screenshot -h string:image-path:"$1" "Screenshot saved" "$(basename "$1")"', "sh", file]);
    }

    function take(target: var): void {
        const file = newFile();
        // Detached, so a second quick shot is not dropped.
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && f="$2" && shift 2 && grim "$@" "$f" && wl-copy --type image/png < "$f" && notify-send -a Screenshot -h string:image-path:"$f" "Screenshot saved" "$(basename "$f")"', "sh", root.dir, file, ...target]);
    }

    // grabToImage cannot create the folder, so it is made up front.
    Process {
        id: makeDir
        command: ["mkdir", "-p", root.dir]
    }

    Process {
        id: clients
        // Workspace and windows in one call, so they cannot disagree.
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
