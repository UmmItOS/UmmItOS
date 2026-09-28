pragma Singleton
pragma ComponentBehavior: Bound

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

    // ~/.face when there is one, the bundled picture otherwise.
    property bool hasFace: false
    readonly property url face: hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : Qt.resolvedUrl("avatar.webp")

    FileView {
        path: Quickshell.env("HOME") + "/.face"
        printErrors: false
        onLoaded: root.hasFace = true
        onLoadFailed: root.hasFace = false
    }

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
        // The wake's black curtain is already up: reuse the picture it took before it.
        const pic = Wake.dark > 0 && Wake.shot > 0 ? 'cp "' + Wake.shotDir + '/$o.ppm"' : 'timeout 2 grim -t ppm -o "$o"';
        grab.command = ["sh", "-c", 'mkdir -p -m 700 "$1" && d="$1" && shift && ok=0 && for o; do ' + pic + ' "$d/$o.ppm" || ok=1; done; exit $ok', "sh", shotDir, ...Quickshell.screens.map(s => s.name)];
        grab.running = true;
    }

    function lock(): void {
        // Mid-unlock (the lid closing right after the password): stay locked.
        if (locked && unlocking) {
            release.stop();
            unlocking = false;
            return;
        }
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

        // Lock even if the picture failed, over the plain wallpaper.
        onExited: code => {
            if (code !== 0) {
                root.shot = 0;
                root.release2();
                return;
            }
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
            // Fills the cache LockContent reads; released after unlocking.
            cache: true
            source: root.captured && root.shot > 0 && (root.locked || root.preparing) ? root.shotOf(modelData.name) : ""
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
        interval: Theme.duration.lockWait
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
        if (!checking)
            return;
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
        // A no-op after completed(); kept so an error with no completed() cannot leave it checking.
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
