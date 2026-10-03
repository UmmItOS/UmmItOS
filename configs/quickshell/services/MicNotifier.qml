import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The built-in mic can get stuck after a sleep; only a reboot brings it back, so say so once.
Scope {
    id: root

    property bool warned: false

    Connections {
        function onWoke(): void {
            settle.restart();
        }

        target: Wake
    }

    // After the audio devices have come back from the sleep.
    Timer {
        id: settle

        onTriggered: check.running = true

        interval: 5000
    }

    Process {
        id: check

        onExited: code => {
            if (code === 0) {
                root.warned = false;
            } else if (!root.warned) {
                root.warned = true;
                Notifs.say("Microphone", I18n.t("Microphone stopped working"), I18n.t("It gets stuck after some sleeps. Reboot to fix it."), "critical");
            }
        }

        command: [Quickshell.env("HOME") + "/script/misc/mic-check.sh"]
    }
}
