import QtQuick

// A pill button; primary is filled with the accent. Disabled, it goes flat and dim.
Rectangle {
    id: action

    property string icon
    property string label
    property bool primary: false
    // The resting fill of a plain one: glass on a blurred panel, a tone on an opaque card.
    property color rest: Theme.glass

    readonly property color ink: !action.enabled ? Theme.dim : action.primary ? (hover.hovered ? Theme.scrim(1) : Theme.accentOn) : Theme.fg

    signal clicked

    implicitWidth: row.implicitWidth + Theme.padding.large * 2
    implicitHeight: Theme.control.field
    radius: Theme.rounding.full
    color: !action.enabled ? Theme.glass : action.primary ? (hover.hovered ? Theme.accentText : Theme.accent) : (hover.hovered ? Theme.bgTray : action.rest)
    scale: tap.pressed ? Theme.pressScale : 1

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
            visible: action.icon !== ""
            text: action.icon
            color: action.ink
            size: Theme.icon.small
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: action.label
            color: action.ink
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
