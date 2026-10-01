pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// Captures once the overlay is gone, so it is not in the shot.
Singleton {
    id: root

    property bool open: false
    property string mode: "region"
    // Picked once on open, so moving the pointer to another monitor does not move it.
    property var screen: null
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

    // From Print until the picture is taken, notices hold still: picking a region takes longer than a notice lasts.
    readonly property bool holding: open || leaving || settle.running || shotMargin.running

    // grim runs detached after the overlay leaves; this covers it.
    Timer {
        id: shotMargin
        interval: Theme.duration.extraLarge
    }

    function start(newMode: string): void {
        if (leaving)
            return;
        mode = newMode;
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        // Cleared first, or a stale window gets framed.
        if (newMode === "window") {
            windows = [];
            clients.running = true;
            makeDir.running = true;
        }
        open = true;
    }

    readonly property string dir: Quickshell.env("HYPRSHOT_DIR") || Quickshell.env("HOME") + "/Pictures/Screenshots"

    // When the last shot went to the clipboard, so its copy pill stays quiet.
    property real delivered: 0

    // grim geometry ("x,y wxh"), held while the overlay leaves.
    property string pendingGeometry: ""

    function region(geometry: string): void {
        pendingGeometry = geometry;
        open = false;
        settle.restart();
    }

    // Print: the focused screen at once; nothing on it needs picking, so no overlay to wait through.
    function screenNow(): void {
        if (open || leaving)
            return;
        take(["-o", Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""]);
    }

    // Long enough for the exit animation, so the overlay is not captured.
    Timer {
        id: settle
        interval: Theme.duration.expressiveFastSpatial + Theme.duration.small
        onTriggered: root.take(["-g", root.pendingGeometry])
    }

    function newFile(): string {
        return root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
    }

    // Runs grim when given its arguments, then copies and announces the file; detached, so a quick second shot is not dropped.
    function deliver(file: string, grimArgs: var): void {
        delivered = Date.now();
        Quickshell.execDetached(["sh", "-c", 'd="$1" f="$2" ok="$3" bad="$4" why="$5"; shift 5; if [ $# -gt 0 ]; then { mkdir -p "$d" && grim "$@" "$f"; } || { notify-send -a Screenshot -u critical "$bad" "$why"; exit 1; }; fi; wl-copy --type image/png < "$f"; notify-send -a Screenshot -h string:image-path:"$f" "$ok" "$(basename "$f")"', "sh", root.dir, file, I18n.t("Screenshot saved"), I18n.t("Screenshot failed"), I18n.t("Could not save to %1").arg(root.dir), ...grimArgs]);
    }

    // A window shot is saved by the shell itself (keeps transparency).
    function saved(file: string): void {
        deliver(file, []);
    }

    function take(target: var): void {
        shotMargin.restart();
        deliver(newFile(), target);
    }

    // grabToImage cannot create the folder, so it is made up front.
    Process {
        id: makeDir
        command: ["mkdir", "-p", root.dir]
    }

    Process {
        id: clients
        // Workspace and windows in one call, so they cannot disagree.
        command: ["sh", "-c", `ws=$(hyprctl activeworkspace -j | jq .id) && hyprctl clients -j | jq --argjson ws "$ws" '[.[] | select(.workspace.id == $ws and .mapped and (.hidden | not) and .size[0] > ${Theme.screenshot.minWindow} and .size[1] > ${Theme.screenshot.minWindow})]'`]
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
            root.screenNow();
        }

        function window(): void {
            root.start("window");
        }
    }
}
