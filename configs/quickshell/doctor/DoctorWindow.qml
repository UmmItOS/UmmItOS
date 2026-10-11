pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    readonly property bool clean: Doctor.finished && Doctor.failed === 0 && Doctor.warned === 0

    onOpened: scope.forceActiveFocus()

    shown: Doctor.open
    name: "doctor"
    scrim: Theme.shade.normal

    MouseArea {
        onClicked: Doctor.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

        Keys.onEscapePressed: Doctor.open = false
        Keys.onReturnPressed: if (!Doctor.running)
            Doctor.run()

        anchors.centerIn: parent
        width: Math.min(Theme.doctor.width, parent.width - Theme.spacing.extraLarge * 2)
        height: Math.min(Theme.doctor.height, parent.height - Theme.spacing.extraLarge * 2)
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal
        focus: true

        MouseArea {
            anchors.fill: parent
        }

        Surface {
            anchors.fill: parent
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: Theme.lift.sheet
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Theme.spacing.extraLarge
            }

            spacing: Theme.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    text: I18n.t("Health check")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.weight: Theme.weight.bold
                }

                Spinner {
                    visible: Doctor.running
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    textFormat: Text.PlainText
                    text: Doctor.running ? I18n.t("Checking…") : win.clean ? I18n.t("All good") : I18n.t("%1 ok · %2 to look at · %3 failed").arg(Doctor.good).arg(Doctor.warned).arg(Doctor.failed)
                    color: Doctor.failed > 0 ? Theme.urgent : win.clean ? Theme.good : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium

                    Behavior on color {
                        FastColor {}
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: I18n.t("Does this machine run what the repo holds: the shell, the scripts, the keybinds and the packages.")
                wrapMode: Text.Wrap
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }

            // One line per check, appearing as the script reports it, the way a package install prints.
            ListView {
                id: list

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.spacing.small
                clip: true
                spacing: Theme.spacing.extraSmall
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: Doctor.lines
                }

                // Follow the newest line while it is being written.
                onCountChanged: if (Doctor.running)
                    positionViewAtEnd()

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.duration.expressiveDefaultEffects
                    }

                    NumberAnimation {
                        property: "x"
                        from: Theme.spacing.extraLarge
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }

                delegate: RowLayout {
                    id: row

                    required property var modelData

                    readonly property color tone: modelData.status === "ok" ? Theme.good : modelData.status === "warn" ? Theme.warn : Theme.urgent

                    width: list.width
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: row.modelData.status === "ok" ? "check_circle" : row.modelData.status === "warn" ? "warning" : "cancel"
                        color: row.tone
                        size: Theme.icon.small
                        fill: 1
                    }

                    Text {
                        Layout.preferredWidth: Theme.doctor.group
                        textFormat: Text.PlainText
                        text: ":: " + I18n.t(row.modelData.group)
                        color: Theme.accentText
                        font.family: "monospace"
                        font.pixelSize: Theme.fontSize.small
                    }

                    Text {
                        Layout.preferredWidth: Theme.doctor.title
                        textFormat: Text.PlainText
                        text: row.modelData.title
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: Theme.weight.medium
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: row.modelData.detail
                        elide: Text.ElideMiddle
                        color: row.modelData.status === "ok" ? Theme.dim : row.tone
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.medium

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("Enter checks again · Esc closes")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }

                Action {
                    onClicked: Doctor.fixScripts()

                    visible: Doctor.fixable && !Doctor.running
                    icon: "sync"
                    label: I18n.t("Update ~/script")
                }

                Action {
                    onClicked: Doctor.run()

                    primary: true
                    icon: "refresh"
                    label: I18n.t("Check again")
                    enabled: !Doctor.running
                }
            }
        }
    }
}
