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
    color: Theme.scrim(0.4)

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
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.lighter(Theme.bg, 1.12)
            }
            GradientStop {
                position: 0.6
                color: Theme.bg
            }
        }

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

            // One continuous cluster holding all four tabs, the same shape the
            // bar uses for its icon group, rather than four tabs floating
            // separately with only the active one carrying a background.
            // Spans the content width so its edges line up with the cards
            // below; a hugging cluster centred in a panel aligns with nothing.
            Surface {
                id: tabCluster

                // Concentric radii: an inner corner only nests inside an outer
                // one when its radius is the outer radius minus the inset.
                // A fixed inner radius makes the first and last tab collide
                // with the cluster's own corner.
                readonly property int inset: Theme.spacing.extraSmall

                Layout.fillWidth: true
                Layout.bottomMargin: Theme.padding.large
                implicitHeight: 68
                radius: Theme.rounding.extraLarge
                tone: Theme.bgTray

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

                            // The selected segment, inset so the cluster stays
                            // continuous around it.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: tabCluster.inset
                                radius: tabCluster.radius - tabCluster.inset
                                color: tab.current ? Theme.accent : "transparent"

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
                                    color: tab.current ? Theme.fg : Theme.dim
                                    fill: tab.current ? 1 : 0
                                    size: Theme.icon.large
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab.modelData.label
                                    color: tab.current ? Theme.fg : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                    font.weight: tab.current ? Theme.weight.medium : Theme.weight.regular
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
