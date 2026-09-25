pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// The lecture pen: draw over a frozen screen, zoom with the wheel.
Singleton {
    id: root

    property bool open: false
    // Picked once on open, so moving the pointer to another monitor does not move it.
    property var screen: null

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        open = true;
    }

    IpcHandler {
        target: "draw"

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.open = false;
        }
    }
}
