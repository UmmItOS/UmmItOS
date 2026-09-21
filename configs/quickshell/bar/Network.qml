pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import ".."

// Opens a flyout under the bar, like the volume control, rather than a third
// kind of panel. Scanning only runs while the flyout is open.
RowLayout {
    id: root

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var active: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null

    property bool popupOpen: false
    // A scan takes a few seconds. Without this the flyout shows an empty box
    // and reads as broken rather than as working.
    property bool scanning: false

    readonly property var networks: wifi ? [...wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)) : []

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

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: {
            if (root.wired?.hasLink ?? false)
                return "lan";
            if (!Networking.wifiEnabled)
                return "wifi_off";
            return root.active ? root.bars(root.active.signalStrength) : "signal_wifi_0_bar";
        }
        color: (root.active || (root.wired?.hasLink ?? false)) ? Theme.fg : Theme.dim
    }

    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    HoverHandler {
        id: barHover
    }

    PopupWindow {
        id: popup

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: Theme.spacing.small

        visible: root.popupOpen
        implicitWidth: 380
        implicitHeight: 420
        color: "transparent"

        // Scanning is only worth its cost while someone is looking at the list.
        Binding {
            target: root.wifi
            property: "scannerEnabled"
            value: root.popupOpen
            when: root.wifi !== null
        }

        HoverHandler {
            id: popupHover
        }

        Timer {
            running: root.popupOpen && !popupHover.hovered && !barHover.hovered
            interval: 2500
            onTriggered: root.popupOpen = false
        }

        Surface {
            anchors.fill: parent
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: 1.12

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.padding.large
                }
                spacing: Theme.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    Text {
                        text: "Wi-Fi"
                        color: Theme.fg
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.larger
                        font.weight: Theme.weight.bold
                    }

                    MaterialIcon {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        visible: root.scanning && root.networks.length > 0
                        text: "progress_activity"
                        color: Theme.dim
                        size: Theme.icon.small

                        RotationAnimation on rotation {
                            running: root.scanning
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }

                    // A switch, because the radio is a state rather than an action.
                    Rectangle {
                        implicitWidth: 46
                        implicitHeight: 26
                        radius: height / 2
                        color: Networking.wifiEnabled ? Theme.accent : Theme.bgTray

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }

                        Rectangle {
                            x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: width / 2
                            color: Theme.fg

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                // Every empty case says which one it is.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !Networking.wifiEnabled || !root.wifi || root.networks.length === 0
                    spacing: Theme.spacing.medium

                    Item {
                        Layout.fillHeight: true
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!root.wifi)
                                return "wifi_off";
                            if (!Networking.wifiEnabled)
                                return "wifi_off";
                            return root.scanning ? "progress_activity" : "wifi_find";
                        }
                        color: Theme.dim
                        size: Theme.icon.large

                        RotationAnimation on rotation {
                            running: root.scanning && Networking.wifiEnabled && root.wifi && root.networks.length === 0
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 900
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (!root.wifi)
                                return "No Wi-Fi adapter";
                            if (!Networking.wifiEnabled)
                                return "Wi-Fi is off";
                            return root.scanning ? "Searching for networks" : "No networks found";
                        }
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }

                    Item {
                        Layout.fillHeight: true
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
                    // Connected first, then strongest.
                    model: root.networks

                    delegate: Rectangle {
                        id: row
                        required property var modelData

                        readonly property bool busy: modelData.stateChanging
                        property bool askingPsk: false

                        width: list.width
                        implicitHeight: askingPsk ? 92 : 46
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
                                Layout.preferredHeight: 46
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
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                    font.weight: row.modelData.connected ? Theme.weight.medium : Theme.weight.regular
                                    elide: Text.ElideRight
                                }

                                MaterialIcon {
                                    visible: row.busy
                                    text: "progress_activity"
                                    color: Theme.dim
                                    size: Theme.icon.small

                                    RotationAnimation on rotation {
                                        running: row.busy
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 900
                                    }
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
                                        anchors.margins: -4
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
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller

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
                            height: 46
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
    }
}
