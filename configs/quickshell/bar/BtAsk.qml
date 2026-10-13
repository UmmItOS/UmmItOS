pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as Bluez
import QtQuick
import ".."

// The Bluetooth pairing agent: bluetoothctl asks yes or no, the shell's dialog answers.
Singleton {
    id: root

    property bool open: false
    // "pair" with a passkey to compare, or "service" for a paired device asking to connect.
    property string kind: ""
    property string passkey: ""
    // Kept after closing, so the dialog's exit still shows them.
    property string name: ""

    function answer(yes: bool): void {
        if (!open)
            return;
        open = false;
        agent.write(yes ? "yes\n" : "no\n");
    }

    // One chunk per question; the question is the last thing in it.
    function heard(chunk: string): void {
        const question = chunk.slice(chunk.lastIndexOf("[agent]"));
        const device = Bluez.Bluetooth.devices.values.find(d => d.pairing) ?? Bluez.Bluetooth.devices.values.find(d => d.state === Bluez.BluetoothDeviceState.Connecting);
        const key = question.match(/Confirm passkey (\d+)/);
        kind = question.includes("Authorize service") ? "service" : "pair";
        passkey = key ? key[1] : "";
        name = device?.name || I18n.t("A Bluetooth device");
        open = true;
    }

    Process {
        id: agent

        onStarted: write("default-agent\n")
        onExited: retry.start()

        running: true
        stdinEnabled: true
        command: ["bluetoothctl"]

        // Questions end without a newline, so split on their ending instead.
        // ponytail: a pairing cancelled by the device leaves the dialog up; the late answer is ignored by bluetoothctl.
        stdout: SplitParser {
            splitMarker: "(yes/no): "
            onRead: data => root.heard(data)
        }
    }

    // bluetoothd restarted, or was not up yet.
    Timer {
        id: retry

        onTriggered: agent.running = true

        interval: Theme.duration.imeRetry
    }
}
