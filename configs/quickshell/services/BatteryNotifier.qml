import Quickshell
import Quickshell.Services.UPower
import QtQuick
import ".."

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
            Notifs.say("Battery", I18n.t("Battery critically low"), I18n.t("%1% left. Plug in now.").arg(pct), "critical");
        } else if (pct <= root.lowThreshold && root.warned > root.lowThreshold) {
            root.warned = root.lowThreshold;
            Notifs.say("Battery", I18n.t("Battery low"), I18n.t("%1% left.").arg(pct), "normal");
        }
    }

    Connections {
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
                Notifs.say("Battery", I18n.t("Battery full"), I18n.t("Charged. You can unplug."), "low");
        }

        target: root.battery
        enabled: root.present
    }

    // The charger reports at once; the battery lags seconds behind.
    Connections {
        function onOnBatteryChanged() {
            if (!root.primed)
                return;
            if (!UPower.onBattery) {
                root.pluggedIn();
                Notifs.say("Battery", I18n.t("Charging"), I18n.t("%1%").arg(root.percent()), "low");
            } else {
                Notifs.say("Battery", I18n.t("On battery"), I18n.t("%1%").arg(root.percent()), "low");
            }
        }

        target: UPower
        enabled: root.present
    }

    // One pass to settle the starting state, then arm.
    Timer {
        onTriggered: {
            root.lastState = root.battery?.state ?? -1;
            root.primed = true;
        }

        running: true
        interval: 1200
    }
}
