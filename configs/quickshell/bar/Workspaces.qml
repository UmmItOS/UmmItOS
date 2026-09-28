pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

RowLayout {
    spacing: Theme.spacing.small

    Repeater {
        // Special workspaces have negative ids.
        model: ScriptModel {
            values: [...Hyprland.workspaces.values].filter(w => w && w.id > 0)
        }

        Rectangle {
            id: pill
            required property HyprlandWorkspace modelData

            readonly property bool focused: modelData?.focused ?? false

            readonly property real targetWidth: focused ? Math.max(30, label.implicitWidth + Theme.padding.large) : 10
            readonly property real targetHeight: focused ? 24 : 10

            implicitWidth: targetWidth
            implicitHeight: targetHeight
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
                color: Theme.accentOn
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.bold: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }
            }

            // Only once grown: a resizing layer rebuilds its blur every frame.
            layer.enabled: pill.focused && pill.implicitWidth === pill.targetWidth && pill.implicitHeight === pill.targetHeight
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
                cursorShape: Qt.PointingHandCursor
                onClicked: pill.modelData?.activate()
            }
        }
    }
}
