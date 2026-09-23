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
            id: surface

            color: "black"

            LockContent {
                anchors.fill: parent
                screenName: surface.screen?.name ?? ""
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
