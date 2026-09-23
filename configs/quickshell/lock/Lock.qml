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
    // The same screen in an ordinary window, for working on the look without
    // locking anything. A right password closes it.
    property bool previewing: false
    readonly property bool shown: locked || previewing

    // Set on a right password: the surfaces play their way out, then the
    // lock is released, so unlocking is a fade and not a cut.
    property bool unlocking: false

    property bool checking: false
    property bool failed: false
    property int attempts: 0
    // Held only until PAM asks for it.
    property string pending: ""

    signal wrong

    // Uncompressed PPM: PNG encoding took ~0.6s a screen, which read as the
    // lock lagging behind the key; PPM is ~25ms.
    // Each screen as it was just before locking, so the lock can fade in
    // from the desktop and back out to it. A lock surface is opaque, so
    // without this the desktop could only pop back when the lock lets go.
    // Kept in the runtime dir (private tmpfs) and deleted after unlocking.
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-lock"
    property int shot: 0
    property bool preparing: false

    function shotOf(screenName: string): string {
        return "file://" + shotDir + "/" + screenName + ".ppm?" + shot;
    }

    // Photograph every screen, then run `then`.
    function capture(then: var): void {
        preparing = true;
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

        // Lock even if the picture failed: a lock that never comes is worse
        // than one that fades in from black.
        onExited: {
            root.shot++;
            waitLimit.restart();
        }
    }

    // Each picture decoded into the image cache before the lock shows. The
    // lock used to open while its picture was still loading, so its first
    // frames showed the dimmed wallpaper and then jumped to the desktop.
    Instantiator {
        id: preload

        model: Quickshell.screens

        Image {
            required property var modelData

            asynchronous: true
            source: root.shot > 0 ? root.shotOf(modelData.name) : ""
            onStatusChanged: root.readyCheck()
        }
    }

    function readyCheck(): void {
        if (!preparing)
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

    // A private PAM stack in the shell's own folder, so no root-owned
    // /etc/pam.d file is needed. pam_unix checks through setuid unix_chkpwd.
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
