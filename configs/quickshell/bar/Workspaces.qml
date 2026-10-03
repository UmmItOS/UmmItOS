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

            readonly property real targetWidth: focused ? Math.max(Theme.bar.workspaceMin, label.implicitWidth + Theme.spacing.large) : Theme.bar.workspaceDot
            readonly property real targetHeight: focused ? Theme.bar.workspace : Theme.bar.workspaceDot

            implicitWidth: targetWidth
            implicitHeight: targetHeight
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            // bgTray vanished against the bar; plain white shouted.
            color: focused ? Theme.accent : modelData?.urgent ? Theme.urgent : Qt.alpha(Theme.accentText, Theme.bar.workspaceIdle)

            // Only once grown: a resizing layer rebuilds its blur every frame.
            layer.enabled: pill.focused && pill.implicitWidth === pill.targetWidth && pill.implicitHeight === pill.targetHeight

            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.accent
                shadowBlur: Theme.bar.workspaceGlowBlur
                shadowOpacity: Theme.bar.workspaceGlow
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }

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
                textFormat: Text.PlainText
                text: pill.modelData?.name ?? ""
                color: Theme.accentOn
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.bold: true

                Behavior on opacity {
                    FastFade {}
                }
            }

            MouseArea {
                onClicked: pill.modelData?.activate()

                anchors.fill: parent
                anchors.margins: -Theme.hitSlop
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
