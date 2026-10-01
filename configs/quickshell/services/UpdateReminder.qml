import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Once the last full upgrade (from pacman.log) is a week old, nags every half hour; transient (-e).
Scope {
    id: root

    readonly property int staleDays: 7
    readonly property int every: 30 * 60 * 1000
    // Not straight away: a shell reload should not nag.
    readonly property int firstCheck: 2 * 60 * 1000

    Process {
        id: last
        command: ["sh", "-c", "tac /var/log/pacman.log | grep -a -m1 'starting full system upgrade'"]
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
                const date = when.toLocaleString(I18n.locale, I18n.t("d MMMM"));
                Quickshell.execDetached(["sh", "-c", `
                    a=$(notify-send -e -a Update -A update="$3" "$1" "$2")
                    [ "$a" = update ] && kitty -e "$HOME/script/misc/update.sh"`, "sh", I18n.t("System not updated for %1 days").arg(days), I18n.t("The last full upgrade was on %1.").arg(date), I18n.t("Update now")]);
            }
        }
    }

    Timer {
        running: true
        interval: root.firstCheck
        onTriggered: last.running = true
    }

    Timer {
        running: true
        repeat: true
        interval: root.every
        onTriggered: last.running = true
    }
}
