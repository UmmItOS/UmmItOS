import QtQuick

// A pill button; primary is filled with the accent. Disabled, it goes flat and dim.
Rectangle {
    id: action

    property string icon
    property string label
    property bool primary: false
    // The resting fill of a plain one: glass on a blurred panel, a tone on an opaque card.
    property color rest: Theme.glass

    readonly property bool hovered: action.enabled && hover.hovered
    readonly property color ink: !action.enabled ? Theme.dim : action.primary ? (action.hovered ? Theme.scrim(1) : Theme.accentOn) : Theme.fg

    signal clicked

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            event.accepted = true;
            if (action.enabled && !event.isAutoRepeat)
                action.clicked();
        }
    }
    Accessible.onPressAction: if (action.enabled) action.clicked()

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: action.label
    implicitWidth: row.implicitWidth + Theme.spacing.large * 2
    implicitHeight: Theme.control.field
    radius: Theme.rounding.full
    color: !action.enabled ? Theme.glass : action.primary ? (action.hovered ? Theme.accentText : Theme.accent) : (action.hovered ? Theme.bgTray : action.rest)
    scale: tap.pressed ? Theme.pressScale : 1

    Behavior on color {
        FastColor {}
    }

    Behavior on scale {
        PressAnim {}
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacing.extraSmall
        width: parent.width - Theme.spacing.large * 2
        height: Theme.spacing.hair
        radius: Theme.rounding.full
        color: action.ink
        opacity: action.enabled && action.activeFocus ? 1 : 0

        Behavior on opacity {
            FastFade {}
        }

        Behavior on color {
            FastColor {}
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
            textFormat: Text.PlainText
            text: action.label
            color: action.ink
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Theme.weight.medium
        }
    }

    HoverHandler {
        id: hover

        cursorShape: action.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tap

        onTapped: action.clicked()
    }
}
