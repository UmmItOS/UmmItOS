import Quickshell
import Quickshell.Bluetooth as Bluez
import Quickshell.Networking
import QtQuick

// Says when Wi-Fi joins or leaves a network and when a Bluetooth device
// connects or drops, through notify-send like the battery notices. Changes
// are compared after they settle, so hopping networks is one notice, not a
// "disconnected" and a "connected".
Scope {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property string network: root.wifi?.networks.values.find(n => n.connected)?.name ?? ""
    readonly property var devices: [...Bluez.Bluetooth.devices.values].filter(d => d.connected).map(d => d.name || d.address)

    // What was last said, compared against once things settle.
    property string lastNetwork: ""
    property var lastDevices: []
    // Nothing should fire because the shell started or reloaded.
    property bool primed: false

    function notify(app: string, summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", app, summary, body]);
    }

    function settleNow(): void {
        if (root.network !== root.lastNetwork) {
            if (root.network !== "")
                root.notify("Wi-Fi", "Wi-Fi connected", root.network);
            else
                root.notify("Wi-Fi", "Wi-Fi disconnected", root.lastNetwork);
            root.lastNetwork = root.network;
        }
        for (const name of root.devices)
            if (!root.lastDevices.includes(name))
                root.notify("Bluetooth", "Connected", name);
        for (const name of root.lastDevices)
            if (!root.devices.includes(name))
                root.notify("Bluetooth", "Disconnected", name);
        root.lastDevices = root.devices;
    }

    onNetworkChanged: if (primed) settle.restart()
    onDevicesChanged: if (primed) settle.restart()

    Timer {
        id: settle
        interval: 1500
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
