pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// Alt+Tab over workspaces. Hyprland delivers the shortcut through the
// global-shortcuts protocol; the window takes keyboard focus once open so it
// can see the Alt release itself, which is what makes it behave like a real
// switcher rather than a dialog.
Singleton {
    id: root

    property bool open: false
    property int index: 0
    // Pinned: the Alt release stops dismissing the switcher, so it can be held
    // on screen — to photograph it, or to read it without keeping a finger on
    // the modifier. Enter or Escape still close it.
    property bool pinned: false
    // Opened as the overview (hot corner), not Alt+Tab: it zooms out of the
    // current workspace on the way in and into the chosen one on the way out.
    property bool overviewing: false
    // Bumped when the hot corner fires, so the window can ripple the corner.
    property int cornerHits: 0

    // Entries go null while Hyprland creates and destroys workspaces, so the
    // list is filtered before anything reads an id off it.
    readonly property var workspaces: [...Hyprland.workspaces.values].filter(w => w).sort((a, b) => a.id - b.id)

    function step(delta: int): void {
        const count = workspaces.length;
        if (count === 0)
            return;

        if (!open) {
            open = true;
            // Opening starts from the workspace you are on, so the first Tab
            // lands on the next one rather than reselecting the current.
            // Compared against Hyprland.focusedWorkspace rather than scanning
            // for a `focused` flag: the flag is per-monitor, so on a workspace
            // it did not consider focused the scan returned -1 and the switch
            // started from the first workspace instead of the current one.
            const here = workspaces.indexOf(Hyprland.focusedWorkspace);
            index = here < 0 ? 0 : here;
        }
        index = (index + delta + count) % count;
    }

    // What the Alt release runs. Pinning is the whole reason this is not just
    // commit(): the compositor's release bind is authoritative and would
    // otherwise close the switcher the moment the modifier came up.
    function release(): void {
        if (pinned)
            return;
        commit();
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

    // Every workspace at once, GNOME-overview style, from the hot corner:
    // opens on the current one and stays up without Alt held. The corner
    // again, Esc, or picking a workspace closes it.
    function overview(fromCorner: bool): void {
        if (fromCorner)
            cornerHits++;
        if (open)
            return cancel();
        if (grab.running)
            return;
        // A full-resolution picture of the screen first, for the zoom to
        // start from (uncompressed; ~25ms). Opens either way.
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

    Process {
        id: grab
        onExited: code => {
            root.shotCount++;
            root.shotReady = code === 0;
            root.overviewing = true;
            root.step(0);
            root.startIndex = root.index;
            root.pinned = true;
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
        onTriggered: root.overviewing = false
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "switcherNext"
        description: "Cycle workspaces forward"
        onPressed: root.step(1)
    }

    // Hyprland's bind layer consumes Alt+Tab, so the Alt release may never
    // reach the surface. A release bind from the compositor is authoritative.
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
        onPressed: root.step(-1)
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.step(1);
        }

        function prev(): void {
            root.step(-1);
        }

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
