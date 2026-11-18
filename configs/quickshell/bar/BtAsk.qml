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

    // A device's name reaches the same output as it was sent, so only a last line that is the agent's own
    // question, right after BlueZ's "Request ..." line, counts. The request carries no address, so the name is
    // known only for the device this computer is pairing.
    function heard(chunk: string): void {
        const lines = chunk.replace(/\x1b\[[0-9;]*[A-Za-z]|[\x01\x02]/g, "").split(/[\r\n]+/).map(l => l.trim()).filter(l => l !== "");
        const asked = lines[lines.length - 2] ?? "";
        const question = (lines[lines.length - 1] ?? "").match(/^\[agent\] (?:Confirm passkey (\d{6})|Accept pairing|Authorize service [0-9A-Fa-f-]+)$/);
        if (!question || !/^(Request confirmation|Request authorization|Authorize service)$/.test(asked))
            return;
        const ours = Bluez.Bluetooth.devices.values.filter(d => d.pairing);
        kind = asked === "Authorize service" ? "service" : "pair";
        passkey = question[1] ?? "";
        name = ours.length === 1 && ours[0].name ? ours[0].name : I18n.t("Unknown device");
        open = true;
    }

    Process {
        id: agent

        onStarted: write("default-agent\n")
        onExited: retry.start()

        running: true
        stdinEnabled: true
        command: ["bluetoothctl"]

        // Questions end without a newline, so split on their ending; heard() checks the rest.
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
