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

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            root.toggle();
        }

        // Not `show`: `qs ipc show` is a subcommand, and the CLI grabs the
        // name before it reaches the handler.
        function tab(index: int): void {
            root.tab = index;
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }
    }
}
