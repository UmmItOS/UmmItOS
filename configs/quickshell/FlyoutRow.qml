import QtQuick

Rectangle {
    id: root

    property bool active: false
    readonly property bool hovered: hover.hovered

    implicitHeight: Theme.control.row
    radius: Theme.rounding.large
    color: root.hovered || root.active ? Theme.bgTray : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.expressiveFastEffects
        }
    }

    HoverHandler {
        id: hover
    }
}
