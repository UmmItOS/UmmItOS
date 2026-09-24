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
    // Three beats, each starting while the one before finishes so they flow:
    // the line draws out from the centre…
    readonly property real draw: 1 - Math.pow(1 - Math.min(1, progress / 0.3), 3)
    // …the black opens from it in a soft circle onto a dim, blurred screen…
    readonly property real lids: beat(0.22, 0.65)
    // …and a soft circle from the centre clears that haze to the sharp screen.
    readonly property real circle: beat(0.5, 1)

    // In-out sine between two points of the progress: gentle at both ends,
    // never starting from a standstill mid-way.
    function beat(from: real, to: real): real {
        const t = Math.min(1, Math.max(0, (progress - from) / (to - from)));
        return (1 - Math.cos(Math.PI * t)) / 2;
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
