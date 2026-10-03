pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    property int current: 0

    onOpened: {
        current = 0;
        scope.forceActiveFocus();
    }

    shown: Session.open
    name: "session"
    scrim: Theme.shade.normal

    MouseArea {
        onClicked: Session.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

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

        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.fill: parent
        focus: true

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

                    implicitWidth: Theme.session.tile
                    implicitHeight: Theme.session.tile

                    // Translate, not `y`: the RowLayout owns y.
                    opacity: 0

                    transform: Translate {
                        id: lift
                    }

                    radius: Theme.rounding.extraLarge
                    color: active ? Theme.accent : Theme.bgTray
                    scale: active ? Theme.session.activeScale : 1

                    layer.enabled: tile.active

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.accent
                        shadowBlur: 1
                        shadowOpacity: Theme.session.glow
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    Behavior on color {
                        FastColor {}
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                        }
                    }

                    Connections {
                        function onOpened(): void {
                            entry.stop();
                            tile.opacity = 0;
                            lift.y = Theme.spacing.large;
                            delay.restart();
                        }

                        target: win
                    }

                    Timer {
                        id: delay

                        onTriggered: entry.start()

                        interval: tile.index * Theme.duration.stagger
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

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.icon
                            color: tile.active ? Theme.accentOn : Theme.fg
                            fill: tile.active ? 1 : 0
                            size: Theme.icon.extraLarge
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: I18n.t(tile.modelData.label)
                            color: tile.active ? Theme.accentOn : Theme.fg
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
                            margins: Theme.spacing.medium
                        }

                        text: tile.modelData.key.toUpperCase()
                        color: tile.active ? Theme.accentOn : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                        font.bold: true
                    }

                    MouseArea {
                        onPositionChanged: mouse => {
                            if (win.pointerMoved(this, mouse.x, mouse.y))
                                win.current = tile.index;
                        }

                        onClicked: Session.run(tile.index)

                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
