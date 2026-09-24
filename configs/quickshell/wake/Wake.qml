pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The screen coming up out of black when the laptop wakes, the way a Pixel
// does: hold() blacks it out on the way to sleep, play() fades the black
// away once it is back. Drawn by WakeWindow over the desktop and by
// LockContent over the lock, which covers every other layer.
Singleton {
    id: root

    // 1 is fully black, 0 is nothing drawn.
    property real dark: 0

    function hold(): void {
        fade.stop();
        dark = 1;
    }

    function play(): void {
        if (dark === 0)
            dark = 1;
        fade.restart();
    }

    NumberAnimation {
        id: fade
        target: root
        property: "dark"
        to: 0
        duration: Theme.duration.wake
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curve.emphasizedDecel
    }

    IpcHandler {
        target: "wake"

        function hold(): void {
            root.hold();
        }

        function play(): void {
            root.play();
        }
    }
}
