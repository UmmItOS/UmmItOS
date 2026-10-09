pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: page

    property bool rejected: false

    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Bar")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Choose what the status bar shows.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    SettingRow {
        title: I18n.t("Latest file change")
        hint: I18n.t("Shows the newest change in a folder, beside the bar's tools.")

        Toggle {
            onToggled: Settings.setBar("watchShow", !Settings.watchShow)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.watchShow
        }
    }

    SettingRow {
        title: I18n.t("Folder to watch")
        hint: page.rejected ? I18n.t("Use a full path, like ~/Projects") : Settings.watchMissing ? I18n.t("That folder does not exist") : I18n.t("Type a folder, then Enter. Empty watches the shell's own folder.")
        warn: page.rejected || Settings.watchMissing
        opacity: Settings.watchShow ? 1 : Theme.disabledOpacity
        enabled: Settings.watchShow

        Behavior on opacity {
            FastFade {}
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: Theme.bgTray

            TextInput {
                id: folder

                Keys.onReturnPressed: page.rejected = !Settings.setWatch(text)
                Keys.onEnterPressed: page.rejected = !Settings.setWatch(text)
                onTextEdited: {
                    page.rejected = false;
                    Settings.watchMissing = false;
                }

                onActiveFocusChanged: if (!activeFocus) {
                    page.rejected = false;
                    Settings.watchMissing = false;
                    text = Qt.binding(() => Settings.tilde(Settings.watchFolder));
                }

                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }

                verticalAlignment: TextInput.AlignVCenter
                text: Settings.tilde(Settings.watchFolder)
                color: Theme.fg
                selectByMouse: true
                clip: true
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: folder.text === ""
                    text: I18n.t("The shell's own folder")
                    color: Theme.dim
                    font: folder.font
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
