pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// GNOME's way: a password asked in the middle of the screen, not in a dropdown.
OverlayWindow {
    id: win

    property bool showText: false

    function submit(): void {
        if (psk.text !== "")
            WifiAsk.connect(psk.text);
    }

    onOpened: {
        psk.text = "";
        win.showText = false;
        psk.forceActiveFocus();
    }

    shown: WifiAsk.open
    name: "wifi-ask"
    scrim: Theme.shade.normal

    MouseArea {
        onClicked: WifiAsk.cancel()

        anchors.fill: parent
    }

    Surface {
        anchors.centerIn: parent
        width: Theme.wifiAsk.card
        height: column.implicitHeight + Theme.spacing.extraLarge * 2
        radius: Theme.rounding.extraLarge
        tone: Theme.bg
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        // Clicks on the card stay on the card.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Theme.spacing.extraLarge
            }

            spacing: Theme.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "wifi_password"
                color: Theme.accentText
                size: Theme.icon.huge
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: I18n.t("Wi-Fi password required")
                color: Theme.fg

                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.large
                    weight: Theme.weight.bold
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: WifiAsk.error !== "" ? WifiAsk.error : I18n.t("Enter the password for “%1”").arg(WifiAsk.name)
                color: WifiAsk.error !== "" ? Theme.urgent : Theme.dim

                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.smaller
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.small
                implicitHeight: Theme.control.field
                radius: Theme.rounding.full
                color: Theme.bgAlt

                TextInput {
                    id: psk

                    Keys.onReturnPressed: win.submit()
                    Keys.onEnterPressed: win.submit()
                    Keys.onEscapePressed: WifiAsk.cancel()

                    anchors {
                        left: parent.left
                        right: eye.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacing.large
                        rightMargin: Theme.spacing.small
                    }

                    clip: true
                    echoMode: win.showText ? TextInput.Normal : TextInput.Password
                    color: Theme.fg

                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: psk.text === ""
                        text: I18n.t("Password")
                        color: Theme.dim
                        font: psk.font
                    }
                }

                BarButton {
                    id: eye

                    onClicked: win.showText = !win.showText

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: Theme.spacing.medium
                    }

                    icon: win.showText ? "visibility_off" : "visibility"
                    label: win.showText ? "Hide password" : "Show password"
                    baseColor: Theme.dim
                    hoverColor: Theme.fg
                    size: Theme.icon.small
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: Theme.spacing.small
                spacing: Theme.spacing.small

                Action {
                    onClicked: WifiAsk.cancel()

                    label: I18n.t("Cancel")
                    rest: Theme.bgAlt
                }

                Action {
                    onClicked: win.submit()

                    label: I18n.t("Connect")
                    primary: true
                    enabled: psk.text !== ""
                }
            }
        }
    }
}
