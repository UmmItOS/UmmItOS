pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// The Wi-Fi networks this computer remembers: signal now, how often joined, how long the current one is up.
ColumnLayout {
    id: page

    // Ticks the current connection's time while the page shows.
    property real now: Date.now()

    readonly property var rows: {
        const live = WifiStats.wifi ? WifiStats.wifi.networks.values : [];
        const counted = WifiStats.data.networks;
        return WifiStats.saved.map(s => ({
                    name: s.name,
                    lastUsed: s.lastUsed,
                    count: counted[s.name]?.count ?? 0,
                    since: counted[s.name]?.since ?? 0,
                    current: s.name === WifiStats.current,
                    signal: live.find(n => n.name === s.name)?.signalStrength ?? -1
                })).sort((a, b) => (b.current - a.current) || (b.count - a.count) || (b.lastUsed - a.lastUsed));
    }

    function bars(signal: real): string {
        if (signal < 0)
            return "signal_wifi_off";
        if (signal > 0.75)
            return "network_wifi";
        if (signal > 0.5)
            return "network_wifi_3_bar";
        return signal > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function detail(row: var): string {
        if (row.current) {
            const minutes = Math.max(0, Math.floor((page.now - row.since) / 60000));
            const hours = Math.floor(minutes / 60);
            return I18n.t("Connected for %1").arg(hours > 0 ? I18n.t("%1 h %2 min").arg(hours).arg(minutes % 60) : I18n.t("%1 minutes").arg(minutes));
        }
        if (row.signal < 0)
            return I18n.t("Out of range · last used %1").arg(Qt.formatDateTime(new Date(row.lastUsed * 1000), I18n.t("d MMM, HH:mm")));
        return I18n.t("In range · last used %1").arg(Qt.formatDateTime(new Date(row.lastUsed * 1000), I18n.t("d MMM, HH:mm")));
    }

    onVisibleChanged: if (visible) {
        page.now = Date.now();
        WifiStats.refresh();
    }

    spacing: Theme.spacing.large

    Timer {
        onTriggered: page.now = Date.now()

        running: page.visible && WifiStats.current !== ""
        repeat: true
        interval: Theme.duration.wifiTick
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Wi-Fi")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Networks this computer remembers. Joins are counted from the first time the shell ran this page's counter.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    Text {
        Layout.fillWidth: true
        visible: page.rows.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: I18n.t("No saved Wi-Fi networks")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
    }

    SettingsList {
        id: list

        spacing: Theme.spacing.small

        // Keyed by name, so a signal change updates a row instead of rebuilding it.
        model: ScriptModel {
            values: page.rows
            objectProp: "name"
        }

        delegate: Rectangle {
            id: card

            required property var modelData

            width: list.width
            implicitHeight: line.implicitHeight + Theme.spacing.large * 2
            radius: Theme.rounding.large
            color: card.modelData.current ? Qt.alpha(Theme.accent, Theme.wifiAsk.tint) : Theme.glass

            RowLayout {
                id: line

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }

                spacing: Theme.spacing.large

                MaterialIcon {
                    text: page.bars(card.modelData.signal)
                    color: card.modelData.current ? Theme.accentText : card.modelData.signal < 0 ? Theme.dim : Theme.fg
                    size: Theme.icon.normal
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: card.modelData.name
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        font.weight: Theme.weight.medium
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: page.detail(card.modelData)
                        elide: Text.ElideRight
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: card.modelData.count
                        color: card.modelData.count > 0 ? Theme.fg : Theme.dim
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.large
                        font.weight: Theme.weight.bold
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: I18n.t("joins")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }
            }
        }
    }
}
