pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

// One row of tiles rather than a 3x2 grid: six actions read faster in a
// line, and the row matches the bar's cluster language. Focus starts on Lock,
// the only action here you cannot regret.
OverlayWindow {
    id: win

    shown: Session.open
    name: "session"
    scrim: 0.5

    property int current: 0

    onOpened: {
        current = 0;
        scope.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Session.open = false
    }

    FocusScope {
        id: scope
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Session.open = false
        Keys.onLeftPressed: win.current = (win.current - 1 + Session.actions.length) % Session.actions.length
        Keys.onRightPressed: win.current = (win.current + 1) % Session.actions.length
        Keys.onReturnPressed: Session.run(win.current)
        Keys.onPressed: event => {
            const hit = Session.indexForKey(event.text);
            if (hit >= 0) {
                win.current = hit;
                Session.run(hit);
                event.accepted = true;
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.spacing.largeIncreased

            Repeater {
                model: Session.actions

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool active: win.current === index

                    implicitWidth: 156
                    implicitHeight: 156

                    // A stagger reads as the menu assembling itself; everything
                    // arriving on the same frame reads as a screenshot. Replayed
                    // on every open, and a Translate rather than `y`, which the
                    // RowLayout owns.
                    opacity: 0
                    transform: Translate {
                        id: lift
                    }

                    Connections {
                        target: win

                        function onOpened(): void {
                            entry.stop();
                            tile.opacity = 0;
                            lift.y = Theme.spacing.large;
                            delay.restart();
                        }
                    }

                    Timer {
                        id: delay
                        interval: tile.index * Theme.duration.stagger
                        onTriggered: entry.start()
                    }

                    ParallelAnimation {
                        id: entry

                        NumberAnimation {
                            target: tile
                            property: "opacity"
                            to: 1
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                        NumberAnimation {
                            target: lift
                            property: "y"
                            to: 0
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                    }
                    radius: Theme.rounding.extraLargeIncreased
                    color: active ? Theme.accent : Theme.bgTray
                    scale: active ? 1.06 : 1

                    layer.enabled: tile.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.accent
                        shadowBlur: 1
                        shadowOpacity: 0.6
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            color: Theme.fg
                            fill: tile.active ? 1 : 0
                            size: Theme.icon.extraLarge
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.label
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
                            font.bold: tile.active
                        }
                    }

                    // The key that runs it, so the menu teaches its own shortcuts.
                    Text {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: Theme.padding.medium
                        }
                        text: tile.modelData.key.toUpperCase()
                        color: tile.active ? Theme.fg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            if (win.pointerMoved(this, mouse.x, mouse.y))
                                win.current = tile.index;
                        }
                        onClicked: Session.run(tile.index)
                    }
                }
            }
        }
    }
}
