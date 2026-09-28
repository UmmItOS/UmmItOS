import QtQuick

Rectangle {
    id: root

    property bool checked: false

    readonly property int knob: Theme.control.toggleKnob
    readonly property int inset: Theme.control.toggleInset

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
        color: root.checked ? Theme.accentOn : Theme.fg

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }

        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
            }
        }
    }

    scale: press.pressed ? Theme.pressScale : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

    MouseArea {
        id: press
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
