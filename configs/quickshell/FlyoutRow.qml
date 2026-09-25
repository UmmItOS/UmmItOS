import QtQuick

Rectangle {
    id: root

    property bool active: false
    readonly property bool hovered: hover.hovered

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
    }
}
