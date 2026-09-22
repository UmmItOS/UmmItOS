pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."

// Opens a flyout under the bar, like Bluetooth and the volume control, rather
// than a third kind of panel. Scanning only runs while the flyout is open.
RowLayout {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var active: root.wifi ? root.wifi.networks.values.find(n => n.connected) ?? null : null
    readonly property bool plugged: root.wired?.hasLink ?? false

    // Connected first, then strongest.
    readonly property var networks: root.wifi ? [...root.wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []

    property bool popupOpen: false
    // A scan takes a few seconds. Without this the flyout shows an empty box
    // and reads as broken rather than as working.
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

    function secured(network: var): bool {
        return network.security !== undefined && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Unknown;
    }

    spacing: Theme.spacing.small

    onPopupOpenChanged: {
        if (popupOpen) {
            scanning = true;
            scanGrace.restart();
        }
    }

    Timer {
        id: scanGrace

        interval: 12000
        onTriggered: root.scanning = false
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
        anchorItem: root
        visible: root.popupOpen
        title: "Wi-Fi"
        busy: root.scanning && root.networks.length > 0
        checked: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        onCloseRequested: root.popupOpen = false

        // Scanning is only worth its cost while someone is looking at the list.
        Binding {
            target: root.wifi
            property: "scannerEnabled"
            value: root.popupOpen
            when: root.wifi !== null
        }

        // Every empty case says which one it is.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !Networking.wifiEnabled || !root.wifi || root.networks.length === 0

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.spacing.medium

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.searching
                    text: root.wifi && Networking.wifiEnabled ? "wifi_find" : "wifi_off"
                    color: Theme.dim
                    size: Theme.icon.large
                }

                Spinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.searching
                    size: Theme.icon.large
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (!root.wifi)
                            return "No Wi-Fi adapter";
                        if (!Networking.wifiEnabled)
                            return "Wi-Fi is off";
                        return root.scanning ? "Searching for networks" : "No networks found";
                    }
                    color: Theme.dim
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.normal
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Networking.wifiEnabled && root.wifi && root.networks.length > 0
            clip: true
            spacing: Theme.spacing.extraSmall
            boundsBehavior: Flickable.StopAtBounds
            model: root.networks

            delegate: Rectangle {
                id: row

                required property var modelData

                readonly property bool busy: row.modelData.stateChanging
                readonly property int lineHeight: 46

                property bool askingPsk: false

                width: list.width
                implicitHeight: row.askingPsk ? row.lineHeight * 2 : row.lineHeight
                radius: Theme.rounding.large
                color: rowHover.hovered || row.modelData.connected ? Theme.bgTray : "transparent"

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                HoverHandler {
                    id: rowHover
                }

                ColumnLayout {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: Theme.padding.medium
                        rightMargin: Theme.padding.medium
                    }
                    spacing: Theme.spacing.extraSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: row.lineHeight
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            text: root.bars(row.modelData.signalStrength)
                            color: row.modelData.connected ? Theme.accentText : Theme.fg
                            size: Theme.icon.small
                        }

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            color: Theme.fg
                            elide: Text.ElideRight
                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.smaller
                                weight: row.modelData.connected ? Theme.weight.medium : Theme.weight.regular
                            }
                        }

                        Spinner {
                            visible: row.busy
                        }

                        MaterialIcon {
                            visible: !row.busy && root.secured(row.modelData)
                            text: "lock"
                            color: Theme.dim
                            size: Theme.icon.small
                        }

                        MaterialIcon {
                            visible: !row.busy && row.modelData.known && rowHover.hovered
                            text: "link_off"
                            color: Theme.dim
                            size: Theme.icon.small

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.spacing.extraSmall
                                onClicked: row.modelData.forget()
                            }
                        }
                    }

                    // Only asked for when the network is new and secured.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.padding.medium
                        implicitHeight: 34
                        radius: Theme.rounding.full
                        color: Theme.bgAlt
                        visible: row.askingPsk

                        TextInput {
                            id: psk

                            anchors {
                                fill: parent
                                leftMargin: Theme.padding.large
                                rightMargin: Theme.padding.large
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font {
                                family: Theme.font
                                pixelSize: Theme.fontSize.smaller
                            }

                            Keys.onReturnPressed: {
                                row.modelData.connectWithPsk(text);
                                row.askingPsk = false;
                                text = "";
                            }
                            Keys.onEscapePressed: row.askingPsk = false

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: psk.text === ""
                                text: "Password, then Enter"
                                color: Theme.dim
                                font: psk.font
                            }
                        }
                    }
                }

                MouseArea {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    height: row.lineHeight
                    enabled: !row.busy
                    onClicked: {
                        if (row.modelData.connected) {
                            row.modelData.disconnect();
                        } else if (row.modelData.known || !root.secured(row.modelData)) {
                            row.modelData.connect();
                        } else {
                            row.askingPsk = true;
                            psk.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }
}
