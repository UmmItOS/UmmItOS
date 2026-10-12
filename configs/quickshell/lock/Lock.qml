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
    // After the second wrong password: the photo just taken of whoever is there, and when.
    property bool intruder: false
    property string intruderPhoto: ""
    property bool recording: false
    property int frame: 0
    property string intruderAt: ""
    // Held only until PAM asks for it.
    property string pending: ""

    // ~/.face when there is one, the bundled picture otherwise.
    property bool hasFace: false
    readonly property url face: hasFace ? "file://" + Quickshell.env("HOME") + "/.face" : Qt.resolvedUrl("avatar.webp")

    // PPM, not PNG: PNG took ~0.6s a screen and read as lag.
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-lock"
    property int shot: 0
    property bool preparing: false
    // Gates the preload, or the last lock's deleted files count as loaded.
    property bool captured: false

    signal wrong

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
        intruder = false;
        intruderPhoto = "";
        capture(() => locked = true);
    }

    function preview(): void {
        if (previewing) {
            previewing = false;
            intruder = false;
            intruderPhoto = "";
            // The preview's clip was only to look at.
            intruderShot.running = false;
            Quickshell.execDetached(["sh", "-c", 'sleep 1; rm -rf "$1/ummitos-intruder-preview"', "sh", Quickshell.env("XDG_RUNTIME_DIR")]);
        }
        else if (!preparing)
            capture(() => previewing = true);
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
        // The second wrong password: an alarm, a webcam photo of them kept on this machine, and the screen turns to a warning.
        if (attempts === 2) {
            intruder = true;
            intruderAt = Qt.formatDateTime(new Date(), "HH:mm:ss");
            intruderShot.preview = false;
            intruderShot.running = true;
        }
    }

    FileView {
        onLoaded: root.hasFace = true
        onLoadFailed: root.hasFace = false

        path: Quickshell.env("HOME") + "/.face"
        printErrors: false
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

            onStatusChanged: root.readyCheck()

            asynchronous: true
            // Fills the cache LockContent reads; released after unlocking.
            cache: true
            source: root.captured && root.shot > 0 && (root.locked || root.preparing) ? root.shotOf(modelData.name) : ""
        }
    }

    // Never keeps the lock waiting on a picture for long.
    Timer {
        id: waitLimit

        onTriggered: root.release2()

        interval: Theme.duration.lockWait
    }

    Process {
        id: forget

        command: ["rm", "-rf", root.shotDir]
    }

    Timer {
        id: release

        onTriggered: {
            root.locked = false;
            root.previewing = false;
            root.unlocking = false;
            forget.running = true;
        }

        interval: Theme.duration.expressiveDefaultSpatial
    }

    // A private PAM stack: no /etc/pam.d file needed.
    PamContext {
        id: pam

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
            root.intruder = false;
            root.intruderPhoto = "";
            root.unlocking = true;
            release.restart();
        }

        // A no-op after completed(); kept so an error with no completed() cannot leave it checking.
        onError: root.fail()

        configDirectory: Quickshell.shellDir + "/lock/pam"
        config: "password"
    }

    IpcHandler {
        function lock(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }

        function preview(): void {
            root.preview();
        }

        // The intruder alarm in the preview, to see and hear it, with a real photo kept in memory only.
        function alarm(): void {
            if (root.locked)
                return;
            root.intruder = true;
            root.intruderAt = Qt.formatDateTime(new Date(), "HH:mm:ss");
            root.intruderPhoto = "";
            intruderShot.preview = true;
            intruderShot.running = true;
            if (!root.previewing)
                root.preview();
        }

        target: "lock"
    }

    // The alarm, again and again while the warning is up; a correct unlock or closing the preview stops it at once.
    // Set by hand, not bound: the loop's restart would break a binding and then nothing could stop it.
    readonly property bool sirenOn: intruder && shown
    onSirenOnChanged: siren.running = sirenOn

    Process {
        id: siren

        command: ["pw-play", Sounds.dir + "/intruder"]
        onExited: if (root.sirenOn)
            Qt.callLater(() => siren.running = root.sirenOn)
    }

    Process {
        id: intruderShot

        // A preview's photo stays in memory; a real one is kept.
        property bool preview: false

        command: ["sh", "-c", 'd=$(readlink -f "$1"); for s in "$d/../../script/misc/intruder.sh" "$HOME/script/misc/intruder.sh"; do [ -x "$s" ] && exec "$s" "$2"; done', "sh", Quickshell.shellDir, preview ? "--preview" : ""]
        onRunningChanged: if (!running)
            root.recording = false

        stdout: SplitParser {
            onRead: line => {
                if (root.intruder && line !== "") {
                    root.intruderPhoto = "file://" + line;
                    root.recording = true;
                }
            }
        }
    }

    // The camera writes a new frame eight times a second; the query defeats Qt's image cache.
    Timer {
        running: root.recording && root.shown
        repeat: true
        interval: Theme.lock.liveFrame
        onTriggered: root.frame++
    }
}
