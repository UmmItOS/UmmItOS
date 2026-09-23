import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import ".."

// The real lock, one surface per screen, and a preview of the same content in
// an ordinary window.
Scope {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface

            color: "black"

            LockContent {
                anchors.fill: parent
                // The surface's screen is not set yet when this is built, which
                // left the desktop picture unnamed on a real lock; the focused
                // monitor is the right one until it is.
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
