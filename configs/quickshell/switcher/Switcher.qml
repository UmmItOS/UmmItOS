pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool open: false
    property int index: 0
    // Pinned: the Alt release no longer closes it.
    property bool pinned: false
    property bool overviewing: false
    // The hot corner fired; the window ripples the corner.
    signal cornerHit

    // Entries go null while workspaces are created and destroyed.
    readonly property var workspaces: [...Hyprland.workspaces.values].filter(w => w && w.id > 0).sort((a, b) => a.id - b.id)

    function step(delta: int): void {
        const count = workspaces.length;
        if (count === 0)
            return;

        if (!open) {
            open = true;
            // Not a `focused` scan: that flag is per monitor.
            const here = workspaces.indexOf(Hyprland.focusedWorkspace);
            index = here < 0 ? 0 : here;
        }
        index = (index + delta + count) % count;
    }

    // The compositor's release bind would otherwise ignore the pin.
    function release(): void {
        if (pinned)
            return;
        commit();
    }

    // The overview flag outlives its close by the exit.
    function cycle(delta: int): void {
        if (!open)
            overviewing = false;
        step(delta);
    }

    function commit(): void {
        if (!open)
            return;
        open = false;
        pinned = false;
        const target = workspaces[index];
        if (target && target !== Hyprland.focusedWorkspace)
            target.activate();
    }

    function cancel(): void {
        open = false;
        pinned = false;
    }

    function overview(fromCorner: bool): void {
        if (fromCorner)
            cornerHit();
        if (open)
            return cancel();
        if (grab.running || warming)
            return;
        warming = true;
        // Full-resolution picture for the zoom to start from (~25ms, PPM).
        shotReady = false;
        grab.command = ["sh", "-c", 'mkdir -p -m 700 "$(dirname "$1")" && grim -t ppm -o "$2" "$1"', "sh", shotPath, Hyprland.focusedMonitor?.name ?? ""];
        grab.running = true;
    }

    readonly property string shotPath: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-overview/screen.ppm"
    property bool shotReady: false
    property int shotCount: 0
    readonly property string shotUrl: "file://" + shotPath + "?" + shotCount
    // The workspace the overview opened on: the picture only matches it.
    property int startIndex: -1
    // Captures and decode happen here, off the zoom's first frames.
    property bool warming: false

    function reveal(): void {
        if (!warming)
            return;
        warming = false;
        overviewing = true;
        step(0);
        startIndex = index;
        pinned = true;
    }

    Timer {
        id: warmLimit
        interval: 150
        onTriggered: root.reveal()
    }

    Process {
        id: grab
        onExited: code => {
            root.shotCount++;
            root.shotReady = code === 0;
            if (!root.shotReady)
                return root.reveal();
            warmLimit.restart();
        }
    }

    onOpenChanged: {
        // Cleared after the exit has had time to play.
        if (!open)
            overviewDone.restart();
        else
            overviewDone.stop();
    }

    Timer {
        id: overviewDone
        interval: Theme.duration.expressiveDefaultSpatial
        // The picture is let go too, not kept decoded until the next overview.
        onTriggered: {
            root.overviewing = false;
            root.shotReady = false;
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "switcherNext"
        description: "Cycle workspaces forward"
        onPressed: root.cycle(1)
    }

    // Hyprland's bind layer eats the Alt release; its release bind wins.
    GlobalShortcut {
        appid: "quickshell"
        name: "switcherCommit"
        description: "Commit the workspace switch"
        onPressed: root.release()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "switcherPrev"
        description: "Cycle workspaces backward"
        onPressed: root.cycle(-1)
    }

    IpcHandler {
        target: "switcher"

        function commit(): void {
            root.commit();
        }

        function pin(): void {
            root.pinned = !root.pinned;
        }

        function overview(): void {
            root.overview(false);
        }

    }
}
