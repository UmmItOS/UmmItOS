import QtQuick
import ".."

// A pill button; primary is filled with the accent.
Rectangle {
    id: action

    property string icon
    property string label
    property bool primary: false

    signal clicked

    implicitWidth: row.implicitWidth + Theme.padding.large * 2
    implicitHeight: Theme.control.field
    radius: Theme.rounding.full
    color: action.primary ? (hover.hovered ? Theme.accentText : Theme.accent) : (hover.hovered ? Theme.bgTray : Theme.glass)
    scale: tap.pressed ? Theme.popScale : 1

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.duration.expressiveFastEffects
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standard
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: action.icon
            color: action.primary && hover.hovered ? Theme.bg : Theme.fg
            size: Theme.icon.small
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: action.label
            color: action.primary && hover.hovered ? Theme.bg : Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Theme.weight.medium
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap
        onTapped: action.clicked()
    }
}
