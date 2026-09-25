pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    shown: Recorder.open
    name: "record"
    scrim: 0.5

    onOpened: scope.forceActiveFocus()

    MouseArea {
        anchors.fill: parent
        onClicked: Recorder.cancel()
    }

    component Choice: Rectangle {
        id: choice

        property string label
        property string hint
        property bool checked
        signal toggled

        Layout.fillWidth: true
        implicitHeight: Theme.control.row
        radius: Theme.rounding.large
        color: choiceHover.hovered ? Theme.bgTray : "transparent"

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.padding.medium
                rightMargin: Theme.padding.medium
            }
            spacing: Theme.spacing.medium

            MaterialIcon {
                text: choice.checked ? "check_box" : "check_box_outline_blank"
                fill: choice.checked ? 1 : 0
                color: choice.checked ? Theme.accentText : Theme.dim
            }

            Text {
                Layout.fillWidth: true
                text: choice.label
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
            }

            Text {
                text: choice.hint
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }

        HoverHandler {
            id: choiceHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: choice.toggled()
        }
    }

    component Button: Rectangle {
        id: button

        property string label
        property bool primary
        signal clicked

        implicitWidth: buttonLabel.implicitWidth + Theme.padding.large * 2
        implicitHeight: Theme.control.field
        radius: Theme.rounding.full
        color: button.primary ? Theme.accent : buttonHover.hovered ? Theme.bgTray : Theme.bgAlt
        scale: buttonTap.pressed ? Theme.popScale : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: button.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: button.primary ? Theme.weight.medium : Theme.weight.regular
        }

        HoverHandler {
            id: buttonHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: buttonTap
            onTapped: button.clicked()
        }
    }

    FocusScope {
        id: scope

        anchors.fill: parent
        focus: true
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        Keys.onEscapePressed: Recorder.cancel()
        Keys.onReturnPressed: Recorder.start()
        Keys.onPressed: event => {
            if (Recorder.counting)
                return;
            if (event.key === Qt.Key_S)
                Recorder.system = !Recorder.system;
            else if (event.key === Qt.Key_M)
                Recorder.mic = !Recorder.mic;
        }

        Surface {
            id: card

            anchors.centerIn: parent
            width: Theme.control.dialog
            height: form.implicitHeight + Theme.padding.extraLarge * 2
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: 1.12

            // Swallows clicks so they do not close the dialog.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: form

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Theme.padding.extraLarge
                }
                spacing: Theme.spacing.small
                opacity: Recorder.counting ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }

                Text {
                    text: "Screen recording"
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.bold: true
                }

                Text {
                    Layout.bottomMargin: Theme.spacing.medium
                    text: "The screen you are on. Which sound goes in?"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                }

                Choice {
                    label: "System sound"
                    hint: "S"
                    checked: Recorder.system
                    onToggled: Recorder.system = !Recorder.system
                }

                Choice {
                    label: "Microphone"
                    hint: "M"
                    checked: Recorder.mic
                    onToggled: Recorder.mic = !Recorder.mic
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing.medium
                    spacing: Theme.spacing.small

                    Text {
                        Layout.fillWidth: true
                        text: !Recorder.system && !Recorder.mic ? "No sound" : Recorder.system && Recorder.mic ? "Both, mixed" : ""
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }

                    Button {
                        label: "Cancel"
                        onClicked: Recorder.cancel()
                    }

                    Button {
                        label: "Start"
                        primary: true
                        onClicked: Recorder.start()
                    }
                }
            }

            // The countdown, in place of the form.
            Item {
                anchors.fill: parent
                visible: Recorder.counting

                Text {
                    id: number

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -Theme.spacing.large
                    text: Recorder.count
                    color: Theme.accentText
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.hero
                    font.bold: true
                    font.features: ({
                            tnum: 1
                        })

                    // Each second lands: in large and faint, settling to size.
                    Connections {
                        target: Recorder
                        function onCountChanged(): void {
                            if (Recorder.counting)
                                land.restart();
                        }
                    }

                    ParallelAnimation {
                        id: land

                        NumberAnimation {
                            target: number
                            property: "scale"
                            from: Theme.landScale
                            to: 1
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasized
                        }
                        NumberAnimation {
                            target: number
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: number.bottom
                    text: "Recording starts. Esc to cancel."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                }
            }
        }
    }
}
