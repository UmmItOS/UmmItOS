import Quickshell
import QtQuick
import ".."

// Shown while a screen recording runs, with its length; a click stops and saves it.
Rectangle {
    id: root

    visible: Recorder.recording
    opacity: Recorder.recording ? 1 : 0
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }
    layer.enabled: opacity < 1
    layer.effect: MotionBlur {
        settled: root.opacity
    }
    implicitWidth: row.implicitWidth + Theme.padding.medium * 2
    implicitHeight: Theme.control.field
    radius: Theme.rounding.full
    color: hover.hovered ? Theme.bgTray : Theme.bgAlt

    SystemClock {
        id: clock
        enabled: Recorder.recording
        precision: SystemClock.Seconds
    }

    function elapsed(): string {
        const s = Math.max(0, Math.floor((clock.date.getTime() - Recorder.since) / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        const two = n => String(n).padStart(2, "0");
        return (h > 0 ? h + ":" + two(m) : m) + ":" + two(sec);
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
                running: Recorder.recording
                loops: Animation.Infinite

                NumberAnimation {
                    to: 0.3
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
            text: root.elapsed()
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
        onTapped: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/script/misc/screen-record.sh"])
    }
}
