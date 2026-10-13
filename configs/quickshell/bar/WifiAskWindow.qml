pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// GNOME's way: a password asked in the middle of the screen, not in a dropdown.
OverlayWindow {
    id: win

    property bool showText: false
    readonly property bool wrong: WifiAsk.error !== ""
    readonly property color mood: win.wrong ? Theme.urgent : Theme.accent

    function submit(): void {
        if (psk.text !== "")
            WifiAsk.connect(psk.text);
    }

    onOpened: {
        psk.text = "";
        win.showText = false;
        psk.forceActiveFocus();
        if (win.wrong)
            no.restart();
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

            spacing: Theme.spacing.small

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Theme.spacing.medium
                implicitWidth: Theme.wifiAsk.badge
                implicitHeight: Theme.wifiAsk.badge
                radius: width / 2
                color: Qt.alpha(win.mood, Theme.wifiAsk.tint)

                Behavior on color {
                    FastColor {}
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: win.wrong ? "lock" : "wifi_password"
                    color: win.wrong ? Theme.urgent : Theme.accentText
                    size: Theme.icon.extraLarge
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: WifiAsk.name
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
                text: win.wrong ? WifiAsk.error : I18n.t("Wi-Fi password required")
                color: win.wrong ? Theme.urgent : Theme.dim

                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.normal
                }

                Behavior on color {
                    FastColor {}
                }
            }

            Rectangle {
                id: field

                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.large
                implicitHeight: Theme.wifiAsk.field
                radius: Theme.rounding.full
                color: win.wrong && psk.text === "" ? Qt.alpha(Theme.urgent, Theme.wifiAsk.tint) : psk.activeFocus ? Theme.bgTray : Theme.bgAlt

                transform: Translate {
                    id: shake
                }

                Behavior on color {
                    FastColor {}
                }

                // A wrong password shakes the field, as the lock screen does.
                SequentialAnimation {
                    id: no

                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: Theme.spacing.medium
                        duration: Theme.duration.shake[0]
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }

                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: -Theme.spacing.medium
                        duration: Theme.duration.shake[1]
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }

                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: Theme.spacing.small
                        duration: Theme.duration.shake[2]
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }

                    NumberAnimation {
                        target: shake
                        property: "x"
                        to: 0
                        duration: Theme.duration.shake[3]
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.standard
                    }
                }

                TextInput {
                    id: psk

                    Keys.onReturnPressed: win.submit()
                    Keys.onEnterPressed: win.submit()
                    Keys.onEscapePressed: WifiAsk.cancel()

                    anchors {
                        left: parent.left
                        right: eye.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacing.largeIncreased
                        rightMargin: Theme.spacing.small
                    }

                    clip: true
                    echoMode: win.showText ? TextInput.Normal : TextInput.Password
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentOn

                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.larger
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
                        rightMargin: Theme.spacing.large
                    }

                    icon: win.showText ? "visibility_off" : "visibility"
                    label: win.showText ? "Hide password" : "Show password"
                    baseColor: Theme.dim
                    hoverColor: Theme.fg
                    size: Theme.icon.normal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.medium
                spacing: Theme.spacing.small

                Action {
                    onClicked: WifiAsk.cancel()

                    // Equal halves: fillWidth alone shares by each button's own width.
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: I18n.t("Cancel")
                    rest: Theme.bgAlt
                }

                Action {
                    onClicked: win.submit()

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "wifi"
                    label: I18n.t("Connect")
                    primary: true
                    enabled: psk.text !== ""
                }
            }
        }
    }
}
