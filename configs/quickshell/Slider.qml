import QtQuick

// A level control: a track, a fill, and a knob that fattens under the finger.
// The master volume and every app stream in the audio flyout are the same
// slider with a different colour.
Item {
    id: root

    property real value: 0
    property color fill: Theme.accentText

    readonly property int thickness: 8
    readonly property int knobSize: 16

    signal moved(real value)

    implicitHeight: 28

    Rectangle {
        id: track

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        implicitHeight: root.thickness
        radius: height / 2
        color: Theme.bgTray

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: root.fill
        }
    }

    Rectangle {
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: drag.pressed ? root.knobSize + Theme.spacing.hair * 2 : root.knobSize
        implicitHeight: implicitWidth
        radius: width / 2
        color: Theme.fg

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        // A slider thin enough to look right is thinner than a finger.
        anchors.margins: -Theme.spacing.small

        // In track coordinates: the enlarged hit area starts left of the
        // track, and reading its own x put every press a margin to the right.
        function apply(x: real): void {
            root.moved(Math.max(0, Math.min(1, drag.mapToItem(track, x, 0).x / track.width)));
        }

        onPressed: event => drag.apply(event.x)
        onPositionChanged: event => {
            if (drag.pressed)
                drag.apply(event.x);
        }
    }
}
