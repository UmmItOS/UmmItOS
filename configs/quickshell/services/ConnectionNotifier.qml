import Quickshell
import Quickshell.Bluetooth as Bluez
import Quickshell.Networking
import QtQuick
import ".."

// Compared after settling, so hopping networks is one notice.
Scope {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property string network: root.wifi?.networks.values.find(n => n.connected)?.name ?? ""
    // By address: names repeat and can arrive late.
    readonly property string devices: [...Bluez.Bluetooth.devices.values].filter(d => d.connected).map(d => d.address).sort().join("\n")

    // What was last said, compared against once things settle.
    property string lastNetwork: ""
    property string lastDevices: ""
    // Nothing should fire because the shell started or reloaded.
    property bool primed: false

    function notify(app: string, summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", app, summary, body]);
    }

    function nameOf(address: string): string {
        const d = [...Bluez.Bluetooth.devices.values].find(d => d.address === address);
        return d?.name || address;
    }

    function settleNow(): void {
        // Quiet after a wake, through sleep, and when the settle fired late.
        const late = Date.now() - settle.since > settle.interval * 3;
        if (quiet.running || Wake.dark > 0 || late) {
            root.lastNetwork = root.network;
            root.lastDevices = root.devices;
            return;
        }
        if (root.network !== root.lastNetwork) {
            if (root.network !== "")
                root.notify("Wi-Fi", "Wi-Fi connected", root.network);
            else
                root.notify("Wi-Fi", "Wi-Fi disconnected", root.lastNetwork);
            root.lastNetwork = root.network;
        }
        const now = root.devices ? root.devices.split("\n") : [];
        const before = root.lastDevices ? root.lastDevices.split("\n") : [];
        for (const address of now)
            if (!before.includes(address))
                root.notify("Bluetooth", "Connected", root.nameOf(address));
        for (const address of before)
            if (!now.includes(address))
                root.notify("Bluetooth", "Disconnected", root.nameOf(address));
        root.lastDevices = root.devices;
    }

    onNetworkChanged: if (primed) settle.start_()
    onDevicesChanged: if (primed) settle.start_()

    Connections {
        target: Wake
        function onWoke(): void {
            quiet.restart();
        }
    }

    Timer {
        id: quiet
        interval: 15000
    }

    Timer {
        id: settle
        interval: 1500

        property real since: 0

        function start_(): void {
            since = Date.now();
            restart();
        }

        onTriggered: root.settleNow()
    }

    // Whatever is connected a moment after start is the baseline.
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root.lastNetwork = root.network;
            root.lastDevices = root.devices;
            root.primed = true;
        }
    }
}
