pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import ".."

// The lock's state and its password check. The surfaces only draw it.
Singleton {
    id: root

    property bool locked: false
    // The lock in an ordinary window, to work on its look.
    property bool previewing: false
    readonly property bool shown: locked || previewing

    property bool unlocking: false

    property bool checking: false
    property bool failed: false
    property int attempts: 0
    // Held only until PAM asks for it.
    property string pending: ""

    signal wrong

    // PPM, not PNG: PNG took ~0.6s a screen and read as lag.
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-lock"
    property int shot: 0
    property bool preparing: false
    // Gates the preload, or the last lock's deleted files count as loaded.
    property bool captured: false

    function shotOf(screenName: string): string {
        return "file://" + shotDir + "/" + screenName + ".ppm?" + shot;
    }

    // Photograph every screen, then run `then`.
    function capture(then: var): void {
        preparing = true;
        captured = false;
        grab.then = then;
        grab.command = ["sh", "-c", 'mkdir -p -m 700 "$1" && d="$1" && shift && for o; do grim -t ppm -o "$o" "$d/$o.ppm"; done', "sh", shotDir, ...Quickshell.screens.map(s => s.name)];
        grab.running = true;
    }

    function lock(): void {
        if (locked || preparing)
            return;
        failed = false;
        attempts = 0;
        capture(() => locked = true);
    }

    function preview(): void {
        if (previewing)
            previewing = false;
        else if (!preparing)
            capture(() => previewing = true);
    }

    Process {
        id: grab

        property var then: null

        // Lock even if the picture failed.
        onExited: {
            root.shot++;
            root.captured = true;
            waitLimit.restart();
        }
    }

    // Decoded before the lock shows, or it opens on the plain wallpaper.
    Instantiator {
        id: preload

        model: Quickshell.screens

        Image {
            required property var modelData

            asynchronous: true
            cache: false
            // Released after unlocking, not kept decoded all session.
            source: root.captured && (root.locked || root.preparing) ? root.shotOf(modelData.name) : ""
            onStatusChanged: root.readyCheck()
        }
    }

    function readyCheck(): void {
        if (!preparing || !captured)
            return;
        for (let i = 0; i < preload.count; i++) {
            const s = preload.objectAt(i)?.status;
            if (s !== Image.Ready && s !== Image.Error)
                return;
        }
        waitLimit.stop();
        release2();
    }

    function release2(): void {
        preparing = false;
        const next = grab.then;
        grab.then = null;
        next?.();
    }

    // Never keeps the lock waiting on a picture for long.
    Timer {
        id: waitLimit
        interval: 300
        onTriggered: root.release2()
    }

    Process {
        id: forget
        command: ["rm", "-rf", root.shotDir]
    }

    function submit(password: string): void {
        if (checking || password === "")
            return;
        pending = password;
        checking = true;
        failed = false;
        if (!pam.start())
            fail();
    }

    function fail(): void {
        checking = false;
        pending = "";
        failed = true;
        attempts++;
        wrong();
    }

    Timer {
        id: release
        interval: Theme.duration.expressiveDefaultSpatial
        onTriggered: {
            root.locked = false;
            root.previewing = false;
            root.unlocking = false;
            forget.running = true;
        }
    }

    // A private PAM stack: no /etc/pam.d file needed.
    PamContext {
        id: pam

        configDirectory: Quickshell.shellDir + "/lock/pam"
        config: "password"

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onCompleted: result => {
            if (result !== PamResult.Success)
                return root.fail();
            root.checking = false;
            root.failed = false;
            root.attempts = 0;
            root.unlocking = true;
            release.restart();
        }
        onError: root.fail()
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }

        function preview(): void {
            root.preview();
        }
    }
}
