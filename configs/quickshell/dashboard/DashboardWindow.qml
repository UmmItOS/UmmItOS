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
        width: 940
        height: 520
        radius: Theme.rounding.extraExtraLarge
        color: Theme.bg

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

            // A plain Row with explicit equal widths: Layout.fillWidth on the
            // delegates left them sized to their own text and bunched up left.
            Item {
                Layout.fillWidth: true
                implicitHeight: 62

                Row {
                    id: tabRow
                    anchors.fill: parent

                    Repeater {
                        model: win.tabs

                        Item {
                            id: tab
                            required property var modelData
                            required property int index

                            readonly property bool current: Dashboard.tab === index

                            width: tabRow.width / win.tabs.length
                            height: tabRow.height

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - Theme.spacing.small
                                height: parent.height
                                radius: Theme.rounding.large
                                color: tab.current ? Theme.bgAlt : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.duration.expressiveFastEffects
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacing.extraSmall

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab.modelData.icon
                                    color: tab.current ? Theme.accentText : Theme.dim
                                    fill: tab.current ? 1 : 0
                                    size: 26
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab.modelData.label
                                    color: tab.current ? Theme.accentText : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.normal
                                    font.bold: tab.current
                                }
                            }

                            TapHandler {
                                onTapped: Dashboard.tab = tab.index
                            }
                        }
                    }
                }
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
