pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

// The focused workspace names itself; the rest are markers. Identity first,
// so the bar answers "where am I" without being read left to right.
RowLayout {
    spacing: Theme.spacing.small

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: pill
            required property HyprlandWorkspace modelData

            readonly property bool focused: modelData.focused

            implicitWidth: focused ? Math.max(30, label.implicitWidth + Theme.padding.large) : 10
            implicitHeight: focused ? 24 : 10
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: focused ? Theme.accent : modelData.urgent ? Theme.urgent : Theme.bgTray

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                }
            }
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            Text {
                id: label
                anchors.centerIn: parent
                opacity: pill.focused ? 1 : 0
                text: pill.modelData.name
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.bold: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: pill.modelData.activate()
            }
        }
    }
}
