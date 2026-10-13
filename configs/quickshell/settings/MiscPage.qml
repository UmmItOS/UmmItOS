import QtQuick
import QtQuick.Layouts
import ".."

// Small switches that belong to no other page.
ColumnLayout {
    id: page

    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Misc")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Small things that have no page of their own.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    SettingRow {
        title: I18n.t("Activate Linux")
        hint: I18n.t("A grey reminder in the corner of the screen, as another system has.")

        Toggle {
            onToggled: Settings.setActivate(!Settings.activateShow)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.activateShow
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
