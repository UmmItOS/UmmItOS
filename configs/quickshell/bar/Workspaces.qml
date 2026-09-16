import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    spacing: 6

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            id: pill
            required property HyprlandWorkspace modelData

            implicitWidth: modelData.focused ? 26 : 14
            implicitHeight: 14
            radius: height / 2
            color: modelData.focused ? Theme.accent : modelData.urgent ? Theme.urgent : Theme.dim

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.standard
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: pill.modelData.activate()
            }
        }
    }
}
