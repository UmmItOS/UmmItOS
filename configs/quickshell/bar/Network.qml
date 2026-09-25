pragma ComponentBehavior: Bound

import Quickshell
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

    // Connected first, then known, then by name. Not by signal: strength
    // changes every scan, and each change rebuilt every row, including the
    // one you were typing a password into. The bars already show strength.
    readonly property var networks: root.wifi ? [...root.wifi.networks.values].sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || a.name.localeCompare(b.name)) : []

    // The password prompt lives here, not in the row, so a row being
    // recreated neither closes it nor loses what was typed.
    property string askingFor: ""
    property string pskDraft: ""

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
        } else {
            askingFor = "";
            pskDraft = "";
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
        // Held only while this flyout is open, so the bar on another screen
        // does not switch it off underneath.
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
                    return "No Wi-Fi adapter";
                if (!Networking.wifiEnabled)
                    return "Wi-Fi is off";
                return root.scanning ? "Searching for networks" : "No networks found";
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
            // A ScriptModel, not the array: it diffs each new array against the last,
            // so an entry that is still there keeps its row instead of every row
            // being rebuilt whenever anything changes.
            model: ScriptModel {
                values: root.networks
            }

            delegate: FlyoutRow {
                id: row

                required property var modelData

                readonly property bool busy: row.modelData.stateChanging
                readonly property int lineHeight: Theme.control.row

                readonly property bool askingPsk: root.askingFor !== "" && root.askingFor === row.modelData.name

                width: list.width
                active: row.modelData.connected
                // The expanded row is as tall as what it holds, not a guess.
                implicitHeight: row.askingPsk ? content.implicitHeight : row.lineHeight

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }
                }

                ColumnLayout {
                    id: content

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
                            visible: !row.busy && row.modelData.known && row.hovered
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
                        implicitHeight: Theme.control.field
                        radius: Theme.rounding.full
                        color: Theme.bgAlt
                        visible: row.askingPsk

                        TextInput {
                            id: psk

                            // A long passphrase scrolls; the dots scrolled off
                            // must not draw outside the field.
                            clip: true
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

                            text: row.askingPsk ? root.pskDraft : ""
                            onTextChanged: {
                                if (row.askingPsk)
                                    root.pskDraft = text;
                            }
                            // A recreated row takes the focus back.
                            Component.onCompleted: {
                                if (row.askingPsk)
                                    forceActiveFocus();
                            }

                            Keys.onReturnPressed: {
                                row.modelData.connectWithPsk(text);
                                root.askingFor = "";
                                root.pskDraft = "";
                            }
                            Keys.onEscapePressed: {
                                root.askingFor = "";
                                root.pskDraft = "";
                            }

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
                            root.pskDraft = "";
                            root.askingFor = row.modelData.name;
                            psk.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }
}
