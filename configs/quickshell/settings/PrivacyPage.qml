pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// What clipboard history remembers, and when it forgets.
ColumnLayout {
    id: page

    spacing: Theme.spacing.large

    component Setting: RowLayout {
        id: setting

        property string title
        property string hint
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
                textFormat: Text.PlainText
                text: setting.hint
                color: Theme.dim
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }

        Item {
            id: slot

            Layout.preferredWidth: Theme.settings.choice
            implicitHeight: Theme.control.field
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Privacy")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Choose what the desktop remembers after you copy.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    Setting {
        title: I18n.t("Save clipboard history")
        hint: I18n.t("Turning this off clears the saved history and current clipboard. Passwords marked sensitive are never saved.")

        Toggle {
            onToggled: Settings.setClipboard("clipboardHistory", !Settings.clipboardHistory)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.clipboardHistory
        }
    }

    Setting {
        title: I18n.t("Clear automatically")
        hint: Settings.clipboardClearMinutes === 0 ? I18n.t("Copied items stay until you clear them.") : I18n.t("Clear the history after the last copied item.")

        Segmented {
            onPicked: value => Settings.setClipboard("clipboardClearMinutes", value)

            anchors.fill: parent
            values: [0, 5, 15, 60]
            labels: [I18n.t("Never"), I18n.t("5 min"), I18n.t("15 min"), I18n.t("1 hour")]
            current: Settings.clipboardClearMinutes
            enabled: Settings.clipboardHistory
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: notice.implicitHeight + Theme.spacing.large * 2
        radius: Theme.rounding.large
        color: Theme.glass

        RowLayout {
            id: notice

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: Theme.spacing.large
                rightMargin: Theme.spacing.large
            }

            spacing: Theme.spacing.medium

            MaterialIcon {
                text: "shield_lock"
                color: Theme.good
                size: Theme.icon.normal
                fill: 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.extraSmall

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("History saved before this update may contain sensitive items. Clear it once.")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Theme.weight.medium
                }

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("Wayland does not reveal which app copied an item, so per-app exclusions are unavailable.")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        Action {
            onClicked: Settings.clearClipboard()

            icon: "delete_sweep"
            label: I18n.t("Clear clipboard now")
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
