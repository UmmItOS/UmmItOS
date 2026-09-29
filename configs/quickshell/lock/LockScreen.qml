import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import ".."

Scope {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface

            color: "black"

            LockContent {
                anchors.fill: parent
                // The surface's screen is unset at build time.
                screenName: surface.screen?.name || (Hyprland.focusedMonitor?.name ?? "")
            }
        }
    }

    OverlayWindow {
        id: preview

        shown: Lock.previewing
        name: "lock-preview"

        LockContent {
            anchors.fill: parent
            screenName: preview.screen?.name ?? ""
        }
    }
}
