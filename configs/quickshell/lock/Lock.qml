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

    function lock(): void {
        if (locked)
            return;
        failed = false;
        attempts = 0;
        locked = true;
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
            root.previewing = !root.previewing;
        }
    }
}
