pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// The shell's language; each is named in itself, so it can be found whatever is showing.
ColumnLayout {
    id: page

    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Language")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Pick the language the desktop uses. Apps keep their own.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    Column {
        Layout.fillWidth: true
        spacing: Theme.spacing.extraSmall

        Repeater {
            model: I18n.languages

            FlyoutRow {
                id: choice

                required property var modelData

                width: parent.width
                active: I18n.lang === choice.modelData.code
                scale: press.pressed ? Theme.pressScale : 1

                Behavior on scale {
                    PressAnim {}
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.spacing.medium
                        rightMargin: Theme.spacing.medium
                    }

                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: choice.active ? "check_circle" : "translate"
                        color: choice.active ? choice.ink : choice.inkDim
                        size: Theme.icon.small
                        fill: choice.active ? 1 : 0
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: choice.modelData.name
                        color: choice.ink
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        font.weight: choice.active ? Theme.weight.medium : Theme.weight.regular
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: choice.modelData.code
                        color: choice.inkDim
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSize.small
                    }
                }

                TapHandler {
                    id: press

                    onTapped: I18n.set(choice.modelData.code)
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
