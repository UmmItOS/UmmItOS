import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Through notify-send, so they land in the history too.
Scope {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool present: (root.battery?.isLaptopBattery ?? false) && (root.battery?.isPresent ?? false)
    readonly property real level: root.battery?.percentage ?? 0

    readonly property int lowThreshold: 20
    readonly property int criticalThreshold: 10

    // Nothing should fire because the shell restarted.
    property bool primed: false
    property int lastState: -1
    // Lowest band warned about, so hovering at 20% warns once.
    property int warned: 100

    // For the charging ripple.
    signal pluggedIn

    function notify(urgency: string, summary: string, body: string): void {
        // No -i: a missing theme icon renders as a checkerboard.
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", urgency, summary, body]);
    }

    function percent(): int {
        return Math.round(root.level * 100);
    }

    onLevelChanged: {
        if (!primed || !present)
            return;

        const pct = root.percent();
        if (root.battery.state === UPowerDeviceState.Charging) {
            if (pct > root.lowThreshold)
                root.warned = 100;
            return;
        }

        if (pct <= root.criticalThreshold && root.warned > root.criticalThreshold) {
            root.warned = root.criticalThreshold;
            root.notify("critical", "Battery critically low", pct + "% left. Plug in now.");
        } else if (pct <= root.lowThreshold && root.warned > root.lowThreshold) {
            root.warned = root.lowThreshold;
            root.notify("normal", "Battery low", pct + "% left.");
        }
    }

    Connections {
        target: root.battery
        enabled: root.present

        function onStateChanged() {
            const state = root.battery.state;
            if (!root.primed) {
                root.lastState = state;
                return;
            }
            if (state === root.lastState)
                return;
            root.lastState = state;

            // Not the brief "fully charged" some drivers report on plug-in.
            if (state === UPowerDeviceState.FullyCharged && root.percent() >= 99)
                root.notify("low", "Battery full", "Charged. You can unplug.");
        }
    }

    // The charger reports at once; the battery lags seconds behind.
    Connections {
        target: UPower
        enabled: root.present

        function onOnBatteryChanged() {
            if (!root.primed)
                return;
            if (!UPower.onBattery) {
                root.pluggedIn();
                root.notify("low", "Charging", root.percent() + "%");
            } else {
                root.notify("low", "On battery", root.percent() + "%");
            }
        }
    }

    // One pass to settle the starting state, then arm.
    Timer {
        running: true
        interval: 1200
        onTriggered: {
            root.lastState = root.battery?.state ?? -1;
            root.primed = true;
        }
    }
}
