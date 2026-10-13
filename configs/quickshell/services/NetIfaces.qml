pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Every connected network interface and what kind it is, re-read whenever NetworkManager reports a change.
Singleton {
    id: root

    // { device, kind, name } per connected interface, loopback and helpers left out.
    property var list: []
    readonly property var main: root.list.find(i => i.kind === "Wi-Fi" || i.kind === "LAN") ?? null
    readonly property bool vpn: root.list.some(i => i.kind === "VPN")

    function kind(device: string, type: string): string {
        if (type === "wifi")
            return "Wi-Fi";
        if (type === "ethernet")
            return "LAN";
        if (["wireguard", "tun", "vpn", "wireguard-vpn"].includes(type))
            return "VPN";
        if (type === "bridge" && (device.startsWith("docker") || device.startsWith("br-")))
            return "Docker";
        if (type === "bridge")
            return "Bridge";
        return "";
    }

    Process {
        id: query

        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    // -t escapes a ":" inside a connection name as "\:".
                    const m = line.match(/^((?:\\.|[^:])*):([^:]*):(connected[^:]*):(.*)$/);
                    const kind = m ? root.kind(m[1], m[2]) : "";
                    if (kind !== "")
                        found.push({
                            device: m[1],
                            kind: kind,
                            name: m[4].replace(/\\(.)/g, "$1")
                        });
                }
                root.list = found;
            }
        }
    }

    // NetworkManager's own event stream, so nothing polls.
    Process {
        id: watch

        onStarted: query.running = true
        onExited: retry.start()

        running: true
        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: settle.restart()
        }
    }

    // One re-read for a burst of events.
    Timer {
        id: settle

        onTriggered: query.running = true

        interval: Theme.duration.netSettle
    }

    Timer {
        id: retry

        onTriggered: watch.running = true

        interval: Theme.duration.imeRetry
    }
}
