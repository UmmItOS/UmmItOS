import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: setting

    property string title
    property string hint
    property bool warn: false
    default property alias control: slot.data

    Layout.fillWidth: true
    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            textFormat: Text.PlainText
            text: setting.title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
            font.weight: Theme.weight.medium
        }

        Text {
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
            text: setting.hint
            color: setting.warn ? Theme.urgent : Theme.dim
            wrapMode: Text.Wrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small

            Behavior on color {
                FastColor {}
            }
        }
    }

    Item {
        id: slot

        Layout.preferredWidth: Theme.settings.choice
        implicitHeight: Theme.control.field
    }
}
