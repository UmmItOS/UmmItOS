pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// Alt+Tab over workspaces. Hyprland delivers the shortcut through the
// global-shortcuts protocol; the window takes keyboard focus once open so it
// can see the Alt release itself, which is what makes it behave like a real
// switcher rather than a dialog.
Singleton {
    id: root

    property bool open: false
    property int index: 0

    readonly property var workspaces: [...Hyprland.workspaces.values].sort((a, b) => a.id - b.id)

    function step(delta: int): void {
        const count = workspaces.length;
        if (count === 0)
            return;

        if (!open) {
            open = true;
            // Opening starts from the workspace you are on, so the first Tab
            // lands on the next one rather than reselecting the current.
            const here = workspaces.findIndex(w => w.focused);
            index = here < 0 ? 0 : here;
        }
        index = (index + delta + count) % count;
    }

    function commit(): void {
        if (!open)
            return;
        open = false;
        const target = workspaces[index];
        if (target && !target.focused)
            target.activate();
    }

    function cancel(): void {
        open = false;
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
        onPressed: root.commit()
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
    }
}
