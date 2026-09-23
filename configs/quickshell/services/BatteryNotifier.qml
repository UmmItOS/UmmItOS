import Quickshell
import Quickshell.Services.UPower
import QtQuick

// The notifications a laptop is expected to make on its own: plugged in,
// unplugged, full, low, nearly empty. Sent through notify-send rather than
// raised directly, so they land in the same server, toast and history as
// everything else.
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
    // The lowest band already warned about, so a battery hovering at 20% does
    // not warn once a second. Cleared when it charges back above the band.
    property int warned: 100

    // For the charging ripple.
    signal pluggedIn

    function notify(urgency: string, summary: string, body: string): void {
        // No -i: the icon hint comes back as an image the card tries to draw,
        // and a name the theme does not have renders as a broken checkerboard.
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

            if (state === UPowerDeviceState.Charging)
                root.pluggedIn();
            if (state === UPowerDeviceState.Charging)
                root.notify("low", "Charging", root.percent() + "%" + (root.battery.timeToFull > 0 ? " · " + Math.round(root.battery.timeToFull / 60) + " min to full" : ""));
            else if (state === UPowerDeviceState.Discharging)
                root.notify("low", "On battery", root.percent() + "%" + (root.battery.timeToEmpty > 0 ? " · " + Math.round(root.battery.timeToEmpty / 60) + " min left" : ""));
            else if (state === UPowerDeviceState.FullyCharged)
                root.notify("low", "Battery full", "Charged. You can unplug.");
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
