pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property int tab: 0

    function toggle(): void {
        open = !open;
    }

    // Clicking the same bar item again closes it.
    function toggleTab(index: int): void {
        if (open && tab === index) {
            open = false;
            return;
        }
        tab = index;
        open = true;
    }

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.toggle();
        }

        // Not `show`: the qs CLI claims that name.
        function tab(index: int): void {
            root.tab = index;
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        // What the bar items call: open on a tab, or close if already there.
        function toggleTab(index: int): void {
            root.toggleTab(index);
        }
    }
}
