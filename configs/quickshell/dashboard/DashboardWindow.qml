pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

PanelWindow {
    id: win

    readonly property var tabs: [
        {
            icon: "dashboard",
            label: "Dashboard"
        },
        {
            icon: "queue_music",
            label: "Media"
        },
        {
            icon: "speed",
            label: "Performance"
        },
        {
            icon: "workspaces",
            label: "Workspaces"
        }
    ]

    visible: Dashboard.open
    // Polling /proc and hwmon only matters while the panel is on screen.
    onVisibleChanged: SysInfo.active = visible

    WlrLayershell.namespace: "ummitos-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Qt.rgba(0, 0, 0, 0.35)

    MouseArea {
        anchors.fill: parent
        onClicked: Dashboard.open = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 52
        width: 900
        height: 470
        radius: Theme.rounding.extraExtraLarge
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        // Swallow clicks so they do not reach the dismiss handler.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: Theme.padding.extraLarge
            }
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.spacing.small
                spacing: 0

                Repeater {
                    model: win.tabs

                    ColumnLayout {
                        id: tab
                        required property var modelData
                        required property int index

                        readonly property bool current: Dashboard.tab === index

                        Layout.fillWidth: true
                        // Equal columns: without a preferred width they size to
                        // their own text and bunch up on the left.
                        Layout.preferredWidth: 1
                        spacing: Theme.spacing.extraSmall

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: tab.modelData.icon
                            color: tab.current ? Theme.accentText : Theme.dim
                            fill: tab.current ? 1 : 0
                            size: Theme.fontSize.large
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tab.modelData.label
                            color: tab.current ? Theme.accentText : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Theme.spacing.extraSmall
                            implicitWidth: tab.current ? 54 : 0
                            implicitHeight: 3
                            radius: Theme.rounding.full
                            color: Theme.accentText

                            Behavior on implicitWidth {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveDefaultSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                                }
                            }
                        }

                        // A handler, not a MouseArea: anchoring an Item inside
                        // a Layout is undefined behavior.
                        TapHandler {
                            onTapped: Dashboard.tab = tab.index
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.padding.large
                currentIndex: Dashboard.tab

                HomeTab {}

                MediaTab {}

                PerformanceTab {}

                WorkspacesTab {}
            }
        }
    }
}
