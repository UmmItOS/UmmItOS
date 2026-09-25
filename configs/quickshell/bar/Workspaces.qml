pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

RowLayout {
    spacing: Theme.spacing.small

    Repeater {
        // Special workspaces have negative ids.
        model: [...Hyprland.workspaces.values].filter(w => w && w.id > 0)

        Rectangle {
            id: pill
            required property HyprlandWorkspace modelData

            readonly property bool focused: modelData?.focused ?? false

            implicitWidth: focused ? Math.max(30, label.implicitWidth + Theme.padding.large) : 10
            implicitHeight: focused ? 24 : 10
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            // bgTray vanished against the bar; plain white shouted.
            color: focused ? Theme.accent : modelData?.urgent ? Theme.urgent : Qt.rgba(Theme.accentText.r, Theme.accentText.g, Theme.accentText.b, 0.28)

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
                text: pill.modelData?.name ?? ""
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

            layer.enabled: pill.focused
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.accent
                shadowBlur: 0.9
                shadowOpacity: 0.55
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                onClicked: pill.modelData?.activate()
            }
        }
    }
}
