pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    shown: Dashboard.open
    name: "dashboard"
    scrim: 0.4
    focusMode: WlrKeyboardFocus.OnDemand

    readonly property var tabs: [
        {
            icon: "dashboard",
            label: "Dashboard"
        },
        {
            icon: "monitoring",
            label: "System"
        },
        {
            icon: "workspaces",
            label: "Workspaces"
        }
    ]

    // Polling /proc and hwmon only matters while the panel is on screen.
    onVisibleChanged: {
        SysInfo.active = visible;
        Players.watched = visible;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Dashboard.open = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.top: parent.top
        // Under the bar, read from the token so a taller bar does not end up
        // on top of it. Capped to the screen, which can be smaller than this.
        anchors.topMargin: Theme.barHeight + Theme.spacing.small
        width: Math.min(940, parent.width - Theme.padding.extraLarge * 2)
        height: Math.min(520, parent.height - anchors.topMargin - Theme.padding.extraLarge)
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

                // One pill that slides between tabs, the way iOS segmented
                // controls move, rather than a highlight per tab that blinks.
                Rectangle {
                    readonly property real slot: tabRow.width / win.tabs.length

                    x: Dashboard.tab * slot + tabCluster.inset
                    y: tabCluster.inset
                    width: slot - tabCluster.inset * 2
                    height: tabCluster.height - tabCluster.inset * 2
                    radius: tabCluster.radius - tabCluster.inset
                    color: Theme.accent

                    // Only while open: a bar item opens the dashboard onto its
                    // tab, and the pill should already be there, not travelling.
                    Behavior on x {
                        enabled: Dashboard.open

                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                        }
                    }
                }

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

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacing.extraSmall
                                // Sinks under the finger, springs back on release.
                                scale: press.pressed ? Theme.pressScale : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.duration.expressiveFastSpatial
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.curve.expressiveFastSpatial
                                    }
                                }

                                MaterialIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab.modelData.icon
                                    color: tab.current ? Theme.fg : Theme.dim
                                    fill: tab.current ? 1 : 0
                                    size: Theme.icon.large

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.duration.expressiveDefaultEffects
                                        }
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: tab.modelData.label
                                    color: tab.current ? Theme.fg : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.smaller
                                    font.weight: tab.current ? Theme.weight.medium : Theme.weight.regular

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.duration.expressiveDefaultEffects
                                        }
                                    }
                                }
                            }

                            TapHandler {
                                id: press
                                onTapped: Dashboard.tab = tab.index
                            }
                        }
                    }
                }
            }

            StackLayout {
                id: pages

                property int last: 0

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.padding.large
                currentIndex: Dashboard.tab

                // The new page drifts in from the side the pill moved toward,
                // so the content and the control agree on direction.
                onCurrentIndexChanged: {
                    if (!Dashboard.open) {
                        last = currentIndex;
                        return;
                    }
                    shift.from = (currentIndex > last ? 1 : -1) * Theme.spacing.extraLarge;
                    last = currentIndex;
                    enter.restart();
                }

                transform: Translate {
                    id: slide
                }

                ParallelAnimation {
                    id: enter

                    NumberAnimation {
                        id: shift
                        target: slide
                        property: "x"
                        to: 0
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                    NumberAnimation {
                        target: pages
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.duration.expressiveSlowEffects
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultEffects
                    }
                }

                HomeTab {}

                SystemTab {}

                WorkspacesTab {}
            }
        }
    }
}
