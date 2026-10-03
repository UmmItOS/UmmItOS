pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Pixel-style wake: hold() blacks out before sleep, play() opens.
Singleton {
    id: root

    // 1 is black, 0 is nothing; everything runs linearly.
    property real dark: 0
    readonly property real progress: 1 - dark
    readonly property real draw: beat(0, Theme.wake.drawEnd)
    readonly property real open: beat(Theme.wake.openStart, 1)
    readonly property real haze: 1 - beat(Theme.wake.hazeStart, 1)

    // PPM, like the lock's: PNG was slow enough to see.
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-wake"
    property int shot: 0

    // A play() that arrived during the capture.
    property bool pending: false

    // For things that should ignore post-resume reconnects.
    signal woke

    // Linear between two points of the progress, clamped to 0 … 1.
    function beat(from: real, to: real): real {
        return Math.min(1, Math.max(0, (progress - from) / (to - from)));
    }

    function shotOf(screenName: string): string {
        return "file://" + shotDir + "/" + screenName + ".ppm?" + shot;
    }

    function hold(): void {
        safety.restart();
        pending = false;
        // Mid-opening: straight back to black, keeping the picture it has.
        if (fade.running) {
            fade.stop();
            dark = 1;
            return;
        }
        if (dark > 0 || capture.running)
            return;
        capture.command = ["sh", "-c", 'd="$1"; shift; mkdir -p -m 700 "$d"; for o; do grim -t ppm -o "$o" "$d/$o.ppm" & done; wait', "sh", shotDir, ...Quickshell.screens.map(s => s.name)];
        capture.running = true;
    }

    function play(): void {
        safety.stop();
        // Let the picture finish rather than kill it half-written.
        if (capture.running) {
            pending = true;
            return;
        }
        open_();
    }

    function open_(): void {
        if (dark === 0)
            dark = 1;
        woke();
        fade.restart();
    }

    // Black only once the picture is taken, or it would picture the black.
    Process {
        id: capture

        // A failed capture falls back to the plain veil.
        onExited: code => {
            root.shot = code === 0 ? root.shot + 1 : 0;
            root.dark = 1;
            if (root.pending) {
                root.pending = false;
                root.open_();
            }
        }
    }

    // hold() alone must never leave the screen black.
    Timer {
        id: safety

        onTriggered: root.play()

        interval: Theme.duration.wakeSafety
    }

    // The whole thing in one go, for trying it out.
    Timer {
        id: trial

        onTriggered: root.play()

        interval: Theme.duration.normal
    }

    // The pictures live in $XDG_RUNTIME_DIR, which is RAM; gone once used.
    Process {
        id: forget

        command: ["rm", "-rf", root.shotDir]
    }

    NumberAnimation {
        id: fade

        onFinished: forget.running = true

        target: root
        property: "dark"
        to: 0
        duration: Theme.duration.wake
        easing.type: Easing.Linear
    }

    IpcHandler {
        function hold(): void {
            root.hold();
        }

        function play(): void {
            root.play();
        }

        function test(): void {
            root.hold();
            trial.restart();
        }

        target: "wake"
    }
}
