import QtQuick

Rectangle {
    id: root

    property bool active: false
    readonly property bool hovered: hover.hovered
    // Content colours: readable on the accent fill once active.
    readonly property color ink: root.active ? Theme.accentOn : Theme.fg
    readonly property color inkDim: root.active ? Qt.alpha(Theme.accentOn, Theme.dim.a) : Theme.dim

    implicitHeight: Theme.control.row
    radius: Theme.rounding.large
    // The one in use is filled with the accent, so it cannot be missed.
    color: root.active ? Theme.accent : root.hovered ? Theme.bgTray : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
}
