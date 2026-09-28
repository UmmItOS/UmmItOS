import QtQuick

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
        implicitWidth: root.knobSize
        implicitHeight: implicitWidth
        radius: width / 2
        color: Theme.fg
        // Grows under the finger by scale, so the track does not relayout.
        scale: drag.pressed ? (root.knobSize + Theme.spacing.hair * 2) / root.knobSize : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastEffects
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.standard
            }
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        // A slider thin enough to look right is thinner than a finger.
        anchors.margins: -Theme.spacing.small
        cursorShape: Qt.PointingHandCursor

        // In track coordinates: the hit area starts left of the track.
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
