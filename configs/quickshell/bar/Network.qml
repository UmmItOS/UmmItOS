pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."

RowLayout {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var active: root.wifi ? root.wifi.networks.values.find(n => n.connected) ?? null : null
    readonly property bool plugged: root.wired?.hasLink ?? false

    // Not by signal: it changes every scan and rebuilt the rows.
    readonly property var networks: root.wifi ? [...root.wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || a.name.localeCompare(b.name)) : []

    // The last failed network and why; cleared by the next attempt.
    property string failedFor: ""
    property string failReason: ""

    property bool popupOpen: false
    property bool scanning: false

    readonly property bool searching: Networking.wifiEnabled && root.wifi && root.scanning

    function bars(strength: real): string {
        // NetworkManager reports 0-100; some backends hand back 0-1.
        const pct = strength > 1 ? strength / 100 : strength;
        if (pct > 0.7)
            return "wifi";
        if (pct > 0.45)
            return "wifi_2_bar";
        if (pct > 0.15)
            return "wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    function failText(reason: int): string {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
        case ConnectionFailReason.WifiClientDisconnected:
            return I18n.t("Wrong password");
        case ConnectionFailReason.WifiAuthTimeout:
            return I18n.t("Timed out");
        case ConnectionFailReason.WifiNetworkLost:
            return I18n.t("Out of range");
        default:
            return I18n.t("Couldn't connect");
        }
    }

    function secured(network: var): bool {
        return network.security !== undefined && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
    }

    onPopupOpenChanged: {
        if (popupOpen) {
            scanning = true;
            scanGrace.restart();
        }
    }

    spacing: Theme.spacing.small

    Timer {
        id: scanGrace

        onTriggered: root.scanning = false

        interval: Theme.duration.scanGrace
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter

        text: {
            if (root.plugged)
                return "lan";
            if (!Networking.wifiEnabled)
                return "wifi_off";
            return root.active ? root.bars(root.active.signalStrength) : "signal_wifi_0_bar";
        }

        color: root.active || root.plugged ? Theme.fg : Theme.dim
    }

    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    Flyout {
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        onCloseRequested: root.popupOpen = false

        anchorItem: root
        visible: root.popupOpen
        title: "Wi-Fi"
        busy: root.scanning && root.networks.length > 0
        checked: Networking.wifiEnabled

        // Only while this flyout is open, so another screen's bar cannot stop it.
        Binding {
            target: root.wifi
            property: "scannerEnabled"
            value: true
            when: root.wifi !== null && root.popupOpen
        }

        // Every empty case says which one it is.
        FlyoutEmpty {
            visible: !Networking.wifiEnabled || !root.wifi || root.networks.length === 0
            searching: root.searching
            icon: root.wifi && Networking.wifiEnabled ? "wifi_find" : "wifi_off"

            text: {
                if (!root.wifi)
                    return I18n.t("No Wi-Fi adapter");
                if (!Networking.wifiEnabled)
                    return I18n.t("Wi-Fi is off");
                return root.scanning ? I18n.t("Searching for networks") : I18n.t("No networks found");
            }
        }

        FlyoutList {
            id: list

            visible: Networking.wifiEnabled && root.wifi && root.networks.length > 0
            values: root.networks
            searching: root.searching
            searchText: I18n.t("Searching for networks")

            delegate: FlyoutRow {
                id: row

                required property var modelData

                readonly property bool busy: row.modelData.stateChanging
                readonly property int lineHeight: Theme.control.row

                readonly property bool failed: root.failedFor !== "" && root.failedFor === row.modelData.name

                function attempt(): void {
                    root.failedFor = "";
                    root.failReason = "";
                }

                width: list.width
                active: row.modelData.connected
                implicitHeight: row.lineHeight

                Connections {
                    function onConnectionFailed(reason: int): void {
                        root.failedFor = row.modelData.name;
                        root.failReason = root.failText(reason);
                        // A rejected password asks again; the other failures are not the password.
                        const secrets = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientDisconnected || reason === ConnectionFailReason.WifiAuthTimeout;
                        if (secrets && root.secured(row.modelData)) {
                            root.popupOpen = false;
                            WifiAsk.ask(row.modelData, root.failReason);
                        }
                    }

                    target: row.modelData
                }

                ColumnLayout {
                    id: content

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: Theme.spacing.medium
                        rightMargin: Theme.spacing.medium
                    }

                    spacing: Theme.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: row.lineHeight
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            text: root.bars(row.modelData.signalStrength)
                            color: row.ink
                            size: Theme.icon.small
                        }

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: row.modelData.name
                            color: row.ink
                            elide: Text.ElideRight

                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.smaller
                                weight: row.modelData.connected ? Theme.weight.medium : Theme.weight.regular
                            }
                        }

                        Text {
                            visible: row.modelData.connected && !row.busy
                            // Says what a click does.
                            text: row.hovered ? I18n.t("Disconnect") : I18n.t("Connected")
                            color: row.ink

                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.small
                                weight: Theme.weight.medium
                            }
                        }

                        Text {
                            visible: opacity > 0
                            opacity: row.failed && !row.busy ? 1 : 0
                            textFormat: Text.PlainText
                            text: root.failReason
                            color: Theme.urgent

                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.small
                                weight: Theme.weight.medium
                            }

                            Behavior on opacity {
                                FastFade {}
                            }
                        }

                        Spinner {
                            visible: row.busy
                            color: row.inkDim
                        }

                        MaterialIcon {
                            visible: !row.busy && root.secured(row.modelData)
                            text: "lock"
                            color: row.inkDim
                            size: Theme.icon.small
                        }

                        BarButton {
                            onClicked: row.modelData.forget()

                            visible: !row.busy && row.modelData.known && row.hovered
                            icon: "delete"
                            label: "Forget network"
                            baseColor: row.inkDim
                            hoverColor: row.ink
                            size: Theme.icon.small
                        }
                    }
                }

                MouseArea {
                    onClicked: {
                        if (row.modelData.connected) {
                            row.modelData.disconnect();
                        } else if (row.modelData.known || !root.secured(row.modelData)) {
                            row.attempt();
                            row.modelData.connect();
                        } else {
                            root.popupOpen = false;
                            WifiAsk.ask(row.modelData, "");
                        }
                    }

                    // Under the content, so the forget button gets its own click.
                    z: -1

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }

                    height: row.lineHeight
                    enabled: !row.busy
                }
            }
        }
    }
}
