import Quickshell
import Quickshell.Io
import QtQuick

// Weekly nag from pacman.log's last full upgrade; transient (-e).
Scope {
    id: root

    readonly property int staleDays: 7
    readonly property int every: 30 * 60 * 1000
    // Not straight away: a shell reload should not nag.
    readonly property int firstCheck: 2 * 60 * 1000

    function check(): void {
        if (!last.running)
            last.running = true;
    }

    Process {
        id: last
        command: ["sh", "-c", "grep -a 'starting full system upgrade' /var/log/pacman.log | tail -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // [2026-09-07T23:52:40+0800] → 2026-09-07T23:52:40+08:00
                const m = text.match(/^\[([^\]]+)([+-]\d\d)(\d\d)\]/);
                if (!m)
                    return;
                const when = new Date(m[1] + m[2] + ":" + m[3]);
                const days = Math.floor((Date.now() - when.getTime()) / 86400000);
                if (days < root.staleDays)
                    return;
                const date = Qt.formatDate(when, "d MMMM");
                Quickshell.execDetached(["sh", "-c", `
                    a=$(notify-send -e -a Update -A update="Update now" "$1" "$2")
                    [ "$a" = update ] && kitty -e "$HOME/script/misc/update.sh"`, "sh", `System not updated for ${days} days`, `The last full upgrade was on ${date}.`]);
            }
        }
    }

    Timer {
        running: true
        interval: root.firstCheck
        onTriggered: root.check()
    }

    Timer {
        running: true
        repeat: true
        interval: root.every
        onTriggered: root.check()
    }
}
