import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property var battery: UPower.displayDevice
    // Desktops report no laptop battery; every state below is false then, so nothing says "charging".
    readonly property bool present: (battery?.isLaptopBattery ?? false) && (battery?.isPresent ?? false)
    readonly property real pct: battery ? battery.percentage : 1
    // Not `state`: every Item already has one, for its States.
    readonly property int charge: battery ? battery.state : UPowerDeviceState.Unknown

    // Charging from the plug, not the battery's report; not at a charge limit.
    readonly property bool charging: present && !full && charge !== UPowerDeviceState.PendingCharge && (!UPower.onBattery || charge === UPowerDeviceState.Charging)
    // Drivers report "fully charged" briefly on plug-in; check the level.
    readonly property bool full: present && charge === UPowerDeviceState.FullyCharged && Math.round(pct * 100) >= Theme.battery.full
    readonly property bool low: present && pct < Theme.battery.low && !charging && !full

    readonly property color tone: {
        if (low)
            return Theme.urgent;
        if (charging || full)
            return Theme.good;
        if (pct < 0.4)
            return Theme.warn;
        return Theme.fg;
    }

    readonly property string glyph: {
        if (full)
            return "battery_full";
        if (charging) {
            if (pct >= 0.9)
                return "battery_charging_90";
            if (pct >= 0.8)
                return "battery_charging_80";
            if (pct >= 0.6)
                return "battery_charging_60";
            if (pct >= 0.5)
                return "battery_charging_50";
            if (pct >= 0.3)
                return "battery_charging_30";
            return "battery_charging_20";
        }
        if (pct < 0.1)
            return "battery_alert";
        if (Math.round(pct * 100) >= 100)
            return "battery_full";
        if (pct >= 0.85)
            return "battery_6_bar";
        if (pct >= 0.7)
            return "battery_5_bar";
        if (pct >= 0.55)
            return "battery_4_bar";
        if (pct >= 0.4)
            return "battery_3_bar";
        if (pct >= 0.25)
            return "battery_2_bar";
        return "battery_1_bar";
    }

    // UPower's estimate in seconds, for the way the battery is going; 0 when it has none yet.
    readonly property int seconds: (charging ? battery?.timeToFull : battery?.timeToEmpty) ?? 0

    function span(total: int): string {
        const minutes = Math.round(total / 60);
        return minutes >= 60 ? I18n.t("%1 h %2 min").arg(Math.floor(minutes / 60)).arg(minutes % 60) : I18n.t("%1 minutes").arg(minutes);
    }

    visible: present
    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: root.glyph
        color: root.tone
        // Filled while charging so the state reads before the number does.
        fill: root.charging || root.full ? 1 : 0

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }

        SequentialAnimation on opacity {
            // Not behind the lock, where nobody sees the bar it redraws.
            running: root.charging && !Lock.locked
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: Theme.pulse.charging
                duration: Theme.duration.extraLarge
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: Theme.duration.extraLarge
                easing.type: Easing.InOutSine
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Math.round(root.pct * 100) + " %"
        color: root.tone
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal

        font.features: ({
                tnum: 1
            })

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }
    }

    // Opens the battery screen: what used the battery and why.
    TapHandler {
        onTapped: Power.toggle()
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    // The level and state, and the time left when UPower knows it.
    Tip {
        anchorItem: root
        rows: [
            {
                glyph: root.glyph,
                text: (root.full ? I18n.t("%1 % · fully charged") : root.charging ? I18n.t("%1 % · charging") : I18n.t("%1 % · on battery")).arg(Math.round(root.pct * 100))
            }
        ].concat(root.seconds > 0 ? [
                {
                    glyph: "schedule",
                    text: (root.charging ? I18n.t("%1 until full") : I18n.t("%1 left")).arg(root.span(root.seconds))
                }
            ] : [])
        wanted: hover.hovered
    }
}
