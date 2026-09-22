import QtQuick

// A switch, because a radio is a state rather than an action. Every dimension
// follows from the knob, so one number resizes it.
Rectangle {
    id: root

    property bool checked: false

    readonly property int knob: 20
    readonly property int inset: 3

    signal toggled

    implicitWidth: root.knob * 2 + root.inset * 2
    implicitHeight: root.knob + root.inset * 2
    radius: height / 2
    color: root.checked ? Theme.accent : Theme.bgTray

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }

    Rectangle {
        x: root.checked ? parent.width - width - root.inset : root.inset
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.knob
        implicitHeight: root.knob
        radius: width / 2
        color: Theme.fg

        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
