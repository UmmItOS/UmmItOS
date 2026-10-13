pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import ".."

// How often each Wi-Fi network was joined and since when the current one is up; counted from the first run.
Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ummitos/wifi.json"
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property string current: root.wifi?.networks.values.find(n => n.connected)?.name ?? ""

    // { networks: { name: { count, since } }, now: name connected at the last save }
    property var data: ({
            networks: {},
            now: ""
        })
    property bool loaded: false
    // At start the network list fills in late; an empty name then is not a disconnect.
    property bool primed: false
    // NetworkManager's saved Wi-Fi: name and last used, in seconds.
    property var saved: []

    function record(): void {
        // The same network as at the last save is a reload or restart, not a new join.
        if (!loaded || !primed || root.wifi === null || data.now === current)
            return;
        const networks = data.networks;
        if (current !== "")
            networks[current] = {
                count: (networks[current]?.count ?? 0) + 1,
                since: Date.now()
            };
        data = {
            networks: networks,
            now: current
        };
        store.setText(JSON.stringify(data));
    }

    function refresh(): void {
        list.running = true;
    }

    onCurrentChanged: record()

    Timer {
        onTriggered: {
            root.primed = true;
            root.record();
        }

        running: true
        interval: Theme.duration.osdArm
    }

    FileView {
        id: store

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (parsed && parsed.networks)
                    root.data = parsed;
            } catch (e) {}
            root.loaded = true;
            root.record();
        }
        onLoadFailed: {
            root.loaded = true;
            root.record();
        }

        path: root.file
        printErrors: false
    }

    Process {
        id: list

        // -t escapes a ":" inside a name as "\:".
        command: ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    const m = line.match(/^((?:\\.|[^:])*):([^:]*):(\d+)$/);
                    if (m && m[2] === "802-11-wireless")
                        rows.push({
                            name: m[1].replace(/\\(.)/g, "$1"),
                            lastUsed: Number(m[3])
                        });
                }
                root.saved = rows;
            }
        }
    }
}
