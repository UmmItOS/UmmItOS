pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// Shots are cut from a frame frozen before the overlay maps: its keyboard grab closes bar flyouts and app menus.
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

    // From Print until the picture is taken, notices hold still: picking a region takes longer than a notice lasts.
    readonly property bool holding: freeze.running || open || leaving || shotMargin.running

    readonly property string frozen: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-shot.ppm"

    readonly property string dir: Settings.shotDir

    // When the last shot went to the clipboard, so its copy pill stays quiet.
    property real delivered: 0

    function start(newMode: string): void {
        if (leaving || freeze.running)
            return;
        mode = newMode;
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        // Cleared first, or a stale window gets framed.
        if (newMode === "window") {
            windows = [];
            clients.running = true;
            makeDir.running = true;
        }
        freeze.command = ["grim", "-t", "ppm", "-o", screen?.name ?? "", frozen];
        freeze.running = true;
    }

    // geometry is global logical "x,y wxh"; the frozen frame is in device pixels, hence the fx scaling.
    function region(geometry: string): void {
        open = false;
        const g = geometry.match(/^(-?\d+),(-?\d+) (\d+)x(\d+)$/);
        const s = screen;
        if (!g || !s)
            return;
        const px = (v, side, total) => `%[fx:round(${side}*${v}/${total})]`;
        take(["magick", frozen, "-crop", `${px(g[3], "w", s.width)}x${px(g[4], "h", s.height)}+${px(g[1] - s.x, "w", s.width)}+${px(g[2] - s.y, "h", s.height)}`, "+repage"]);
    }

    // Print: the focused screen at once; nothing on it needs picking, so no overlay to wait through.
    function screenNow(): void {
        if (open || leaving)
            return;
        take(["grim", "-o", Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""]);
    }

    function newFile(): string {
        return root.dir + "/Screenshot_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
    }

    // Runs the capture command when given one, then copies and announces the file; detached, so a quick second shot is not dropped.
    function deliver(file: string, command: var): void {
        delivered = Date.now();
        Quickshell.execDetached(["sh", "-c", 'd="$1" f="$2" ok="$3" bad="$4" why="$5"; shift 5; if [ $# -gt 0 ]; then { mkdir -p "$d" && "$@" "$f"; } || { notify-send -a Screenshot -u critical "$bad" "$why"; exit 1; }; fi; wl-copy --type image/png < "$f"; notify-send -a Screenshot -h string:image-path:"$f" "$ok" "$(basename "$f")"; ocr="$HOME/script/misc/ocr-index.sh"; [ -x "$ocr" ] && "$ocr" "$f" > /dev/null 2>&1', "sh", root.dir, file, I18n.t("Screenshot saved"), I18n.t("Screenshot failed"), I18n.t("Could not save to %1").arg(root.dir), ...command]);
    }

    // A window shot is saved by the shell itself (keeps transparency).
    function saved(file: string): void {
        deliver(file, []);
    }

    function take(target: var): void {
        shotMargin.restart();
        deliver(newFile(), target);
    }

    onOpenChanged: {
        if (!open) {
            leaving = true;
            left.restart();
        }
    }

    Timer {
        id: left

        onTriggered: root.leaving = false

        interval: Theme.duration.expressiveFastSpatial + Theme.duration.small
    }

    // The capture runs detached; this covers it.
    Timer {
        id: shotMargin

        interval: Theme.duration.extraLarge
    }

    // ppm, since PNG encoding is slow enough to read as lag before the overlay.
    Process {
        id: freeze

        onExited: root.open = true
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

        target: "screenshot"
    }
}
