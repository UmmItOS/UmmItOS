import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// The real lock, one surface per screen, and a preview of the same content in
// an ordinary window.
Scope {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            color: "black"

            LockContent {
                anchors.fill: parent
            }
        }
    }

    OverlayWindow {
        shown: Lock.previewing
        name: "lock-preview"

        LockContent {
            anchors.fill: parent
            opacity: Math.min(1, parent.parent?.reveal ?? 1)
        }
    }
}
