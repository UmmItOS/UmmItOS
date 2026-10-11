import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// One battery sample a minute, plugged in or not, for the battery screen (script/misc/battery-log.sh).
Scope {
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: Theme.duration.batteryLog
        onTriggered: sample.running = true
    }

    Process {
        id: sample

        command: ["sh", "-c", 'd=$(readlink -f "$1"); for s in "$d/../../script/misc/battery-log.sh" "$HOME/script/misc/battery-log.sh"; do [ -x "$s" ] && exec nice -n 19 "$s"; done', "sh", Quickshell.shellDir]
    }
}
