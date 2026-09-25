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
    scrim: 0
    focusMode: WlrKeyboardFocus.OnDemand

    readonly property var tabs: ["Dashboard", "System", "Workspaces"]

    // Polling /proc and hwmon, and the player's clock and cava, only matter
    // while the tab that shows them is on screen.
    Binding {
        target: SysInfo
        property: "active"
        value: win.visible && Dashboard.tab === 1
    }

    Binding {
        target: Players
        property: "watched"
        value: win.visible && Dashboard.tab === 0
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Dashboard.open = false
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.top: parent.top
        // Under the bar, read from the token so a taller bar does not end up
        // on top of it. Capped to the screen, which can be smaller than this.
        anchors.topMargin: Theme.barHeight + Theme.spacing.small
        width: Math.min(1100, parent.width - Theme.padding.extraLarge * 2)
        height: Math.min(520, parent.height - anchors.topMargin - Theme.padding.extraLarge)
        radius: Theme.rounding.extraExtraLarge
        color: "transparent"

        Surface {
            anchors.fill: parent
            radius: parent.radius
            tone: Theme.scrim(Theme.panelTint)
            lift: 1.12
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

            // The tabs are the page's headline: the words themselves, set large,
            // with the current one lit and a short bar sliding under it. No tray
            // around them; the panel is already the container.
            Item {
                Layout.fillWidth: true
                implicitHeight: tabRow.implicitHeight + Theme.spacing.small + indicator.height

                Row {
                    id: tabRow
                    spacing: Theme.spacing.extraLarge

                    Repeater {
                        id: tabs
                        model: win.tabs

                        Text {
                            id: tab
                            required property string modelData
                            required property int index

                            readonly property bool current: Dashboard.tab === index

                            text: tab.modelData
                            color: tab.current ? Theme.fg : hover.hovered ? Theme.accent2 : Theme.dim
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.large
                            font.weight: Theme.weight.bold
                            // Sinks under the finger, springs back on release.
                            scale: press.pressed ? Theme.pressScale : 1

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.expressiveFastSpatial
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.duration.expressiveDefaultEffects
                                }
                            }

                            HoverHandler {
                                id: hover
                            }

                            TapHandler {
                                id: press
                                onTapped: Dashboard.tab = tab.index
                            }
                        }
                    }
                }

                // Slides and stretches to the next word, so it travels rather
                // than blinks.
                Rectangle {
                    id: indicator

                    // itemAt() is a call, not a property: read through count so
                    // the binding runs again once the Repeater has built the
                    // words, or the first open finds no word to sit under.
                    readonly property Item target: tabs.count > Dashboard.tab ? tabs.itemAt(Dashboard.tab) : null

                    anchors.bottom: parent.bottom
                    x: target?.x ?? 0
                    width: target?.width ?? 0
                    height: Theme.spacing.extraSmall
                    radius: Theme.rounding.full
                    color: Theme.accentText

                    // Only while open: a bar item opens the dashboard onto its
                    // tab, and the bar should already be there, not travelling.
                    Behavior on x {
                        enabled: Dashboard.open

                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                        }
                    }
                    Behavior on width {
                        enabled: Dashboard.open

                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
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
