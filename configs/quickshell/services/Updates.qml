pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// How many updates wait, checked a while after login, every few hours and when an update run ends; the bar's update button wears a dot for it.
Singleton {
    id: root

    property int count: 0

    // Detached, so a shell reload cannot kill an upgrade halfway; the log below says when it ends.
    function update(): void {
        Quickshell.execDetached(["kitty", "--execute", Quickshell.env("HOME") + "/script/misc/update.sh"]);
    }

    function check(): void {
        if (!scan.running)
            scan.running = true;
    }

    Timer {
        onTriggered: root.check()

        running: true
        repeat: true
        triggeredOnStart: false
        interval: Theme.duration.updatesCheck
    }

    // The first look waits, so login is not slowed by a network call.
    Timer {
        onTriggered: root.check()

        running: true
        interval: Theme.duration.updatesFirst
    }

    // update.sh adds a line when a run ends: read the count again.
    FileView {
        onFileChanged: root.check()

        path: Quickshell.env("HOME") + "/script/misc/update.log"
        watchChanges: true
        printErrors: false
    }

    // checkupdates syncs a copy of the databases, so it needs no root. Offline leaves the old count.
    Process {
        id: scan

        command: ["sh", "-c", `
            command -v checkupdates >/dev/null || exit 0
            out=$(checkupdates 2>/dev/null)
            [ $? -eq 1 ] && exit 1
            n=$(printf '%s\\n' "$out" | sed '/^$/d' | wc -l)
            command -v paru >/dev/null && n=$((n + $(paru -Qua 2>/dev/null | wc -l)))
            echo $n`]

        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text);
                if (!isNaN(n))
                    root.count = n;
            }
        }
    }
}
