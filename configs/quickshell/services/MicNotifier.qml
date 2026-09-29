import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The built-in mic can get stuck after a sleep; only a reboot brings it back, so say so once.
Scope {
    id: root

    property bool warned: false

    Connections {
        target: Wake
        function onWoke(): void {
            settle.restart();
        }
    }

    // After the audio devices have come back from the sleep.
    Timer {
        id: settle
        interval: 5000
        onTriggered: check.running = true
    }

    Process {
        id: check
        command: [Quickshell.env("HOME") + "/script/misc/mic-check.sh"]
        onExited: code => {
            if (code === 0) {
                root.warned = false;
            } else if (!root.warned) {
                root.warned = true;
                Quickshell.execDetached(["notify-send", "-a", "Microphone", "-u", "critical", "Microphone stopped working", "It gets stuck after some sleeps. Reboot to fix it."]);
            }
        }
    }
}
