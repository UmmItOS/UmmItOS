pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The screen coming up out of black when the laptop wakes, the way a Pixel
// does: hold() pictures each screen and then blacks it out on the way to
// sleep; play() draws a line of light and opens a soft circle out of the
// black from it, the picture inside coming from blurred and dim to sharp.
// Drawn by WakeWindow over the desktop and by LockContent over the lock
// (with a plain dim veil there, having no picture of the lock).
Singleton {
    id: root

    // 1 is fully black, 0 is nothing drawn. Runs linearly, and so do the
    // stages below, which everything that draws the wake reads.
    property real dark: 0
    readonly property real progress: 1 - dark
    // Each stage moves at one steady rate from start to end, like counting
    // 0, 1, 2 … 100, rather than easing in and rushing through the middle.
    // The line draws out from the centre…
    readonly property real draw: beat(0, 0.3)
    // …then, starting while it finishes, the black opens in one soft circle
    // whose edge travels at a constant speed, and the screen inside fades
    // from blurred and dim to sharp at a constant rate, finishing together.
    readonly property real open: beat(0.22, 1)
    readonly property real haze: 1 - beat(0.3, 1)

    // Linear between two points of the progress, clamped to 0 … 1.
    function beat(from: real, to: real): real {
        return Math.min(1, Math.max(0, (progress - from) / (to - from)));
    }

    // Each screen pictured just before going black, so the opening can show
    // it blurred and then sharpen it (the live screen cannot be blurred from
    // here; the picture then swaps for it unseen). Uncompressed, like the
    // lock's, because PNG encoding was slow enough to see.
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-wake"
    property int shot: 0

    function shotOf(screenName: string): string {
        return "file://" + shotDir + "/" + screenName + ".ppm?" + shot;
    }

    // Emitted as the wake starts to open, for anything that should ignore
    // the reconnecting that follows a resume (the connection notices).
    signal woke

    // A play() that arrived while the picture was still being taken; the
    // capture finishing starts it.
    property bool pending: false

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

    // Black only once the picture is taken, or it would picture the black.
    Process {
        id: capture
        // Only a clean exit counts as a new picture; otherwise the curtain
        // uses the plain dim veil rather than a half-written file.
        onExited: code => {
            root.shot = code === 0 ? root.shot + 1 : 0;
            root.dark = 1;
            if (root.pending) {
                root.pending = false;
                root.open_();
            }
        }
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

    // hold() on its own must never leave the screen black. Timers run on
    // the monotonic clock, which stops while suspended, so a real sleep
    // still reaches play() from hypridle long before this.
    Timer {
        id: safety
        interval: Theme.duration.wakeSafety
        onTriggered: root.play()
    }

    // The whole thing in one go, for trying it out.
    Timer {
        id: trial
        interval: Theme.duration.normal
        onTriggered: root.play()
    }

    // The pictures live in $XDG_RUNTIME_DIR, which is RAM; gone once used.
    Process {
        id: forget
        command: ["rm", "-rf", root.shotDir]
    }

    NumberAnimation {
        id: fade
        target: root
        property: "dark"
        to: 0
        duration: Theme.duration.wake
        easing.type: Easing.Linear
        onFinished: forget.running = true
    }

    IpcHandler {
        target: "wake"

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
    }
}
