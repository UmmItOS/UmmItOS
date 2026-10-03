pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import ".."

// Shown while a screen recording runs, with its length; a click stops and saves it.
Rectangle {
    id: root

    visible: opacity > 0
    opacity: Recorder.recording ? 1 : 0
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: root.opacity
    }

    implicitWidth: row.implicitWidth + Theme.spacing.medium * 2
    implicitHeight: Theme.control.field
    radius: Theme.rounding.full
    color: hover.hovered ? Theme.bgTray : Theme.bgAlt

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }

    SystemClock {
        id: clock

        enabled: Recorder.recording
        precision: SystemClock.Seconds
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.small

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.spacing.medium
            height: width
            radius: width / 2
            color: Theme.urgent

            SequentialAnimation on opacity {
                running: Recorder.recording && !Lock.locked
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    to: Theme.pulse.recording
                    duration: Theme.duration.extraLarge
                }

                NumberAnimation {
                    to: 1
                    duration: Theme.duration.extraLarge
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Recorder.elapsed(clock.date)
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Theme.weight.medium

            font.features: ({
                    tnum: 1
                })
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Recorder.stop()
    }
}
