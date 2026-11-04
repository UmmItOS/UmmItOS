pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../bar"

// A folder chip of the wallpaper browser; `here` is the open folder.
Rectangle {
    id: chip

    property string path
    property string title
    property int count
    property string here

    readonly property bool active: chip.here === chip.path
    // The parent of the selected child.
    readonly property bool lit: chip.path !== "" && !chip.active && chip.here.startsWith(chip.path + "/")

    signal chosen(string path)

    Accessible.role: Accessible.RadioButton
    Accessible.name: I18n.t("%1, %2 pictures").arg(chip.title).arg(chip.count)
    Accessible.checkable: true
    Accessible.checked: chip.active || chip.lit
    Accessible.onPressAction: chip.chosen(chip.path)
    implicitWidth: label.implicitWidth + Theme.spacing.medium * 2
    implicitHeight: label.implicitHeight + Theme.spacing.small * 2
    radius: Theme.rounding.full
    color: chip.active ? Theme.accent : chipHover.hovered ? Theme.glass : Theme.bgTray
    scale: chipTap.pressed ? Theme.pressScale : 1

    Behavior on color {
        FastColor {}
    }

    Behavior on scale {
        PressAnim {}
    }

    Text {
        id: label

        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: chip.title
        color: chip.active ? Theme.accentOn : chip.lit ? Theme.accentText : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.smaller
        font.weight: Theme.weight.medium
    }

    HoverHandler {
        id: chipHover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: chipTap

        onTapped: chip.chosen(chip.path)
    }
}
