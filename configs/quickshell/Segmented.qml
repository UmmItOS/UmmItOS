pragma ComponentBehavior: Bound

import QtQuick

// One choice of several: the accent pill slides to the picked one.
Item {
    id: root

    required property var values
    required property var labels
    required property var current

    // Only a change of choice slides the pill; the width arriving on first open must not.
    property bool settled: false

    readonly property real cell: width / values.length

    signal picked(var value)

    onWidthChanged: if (width > 0)
        Qt.callLater(() => settled = true)

    implicitHeight: Theme.control.field
    opacity: root.enabled ? 1 : Theme.disabledOpacity

    Behavior on opacity {
        FastFade {}
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rounding.full
        color: Theme.bgTray
    }

    Rectangle {
        width: root.cell
        height: parent.height
        radius: Theme.rounding.full
        color: Theme.accent
        visible: root.values.indexOf(root.current) >= 0

        transform: Translate {
            x: Math.max(0, root.values.indexOf(root.current)) * root.cell

            Behavior on x {
                enabled: root.settled

                NumberAnimation {
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasized
                }
            }
        }
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.values.length

            Item {
                id: choice

                required property int index
                readonly property bool picked: root.current === root.values[choice.index]

                width: root.cell
                height: root.height

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rounding.full
                    color: Theme.glass
                    visible: choiceHover.hovered && !choice.picked
                }

                Text {
                    anchors.centerIn: parent
                    scale: choiceTap.pressed ? Theme.popScale : 1
                    textFormat: Text.PlainText
                    text: root.labels[choice.index]
                    color: choice.picked ? Theme.accentOn : choiceHover.hovered ? Theme.fg : Theme.dim

                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                        weight: choice.picked ? Theme.weight.medium : Theme.weight.regular

                        features: ({
                                tnum: 1
                            })
                    }

                    Behavior on scale {
                        PressAnim {}
                    }

                    Behavior on color {
                        FastColor {}
                    }
                }

                HoverHandler {
                    id: choiceHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: choiceTap

                    onTapped: root.picked(root.values[choice.index])
                }
            }
        }
    }
}
