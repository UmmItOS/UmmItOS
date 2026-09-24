pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The screen coming up out of black when the laptop wakes, the way a Pixel
// does: hold() pictures each screen and then blacks it out on the way to
// sleep; play() opens a soft circle out of the black, through which the
// picture comes from blurred and dim to sharp. Drawn by WakeWindow over the
// desktop and by LockContent (circle only) over the lock.
Singleton {
    id: root

    // 1 is fully black, 0 is nothing drawn. Runs linearly; the two beats
    // below ease on their own, and everything that draws the wake reads them.
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

    function hold(): void {
        fade.stop();
        safety.restart();
        if (dark > 0 || capture.running)
            return;
        capture.command = ["sh", "-c", 'd="$1"; shift; mkdir -p -m 700 "$d"; for o; do grim -t ppm -o "$o" "$d/$o.ppm" & done; wait', "sh", shotDir, ...Quickshell.screens.map(s => s.name)];
        capture.running = true;
    }

    // Black only once the picture is taken, or it would picture the black.
    Process {
        id: capture
        onExited: {
            root.shot++;
            // A play() that arrived meanwhile has already started opening.
            if (!fade.running)
                root.dark = 1;
        }
    }

    function play(): void {
        safety.stop();
        capture.running = false;
        if (dark === 0)
            dark = 1;
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

    NumberAnimation {
        id: fade
        target: root
        property: "dark"
        to: 0
        duration: Theme.duration.wake
        // Linear here: WakeCurtain eases each of its two beats itself.
        easing.type: Easing.Linear
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
