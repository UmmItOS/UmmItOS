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
            text: I18n.t("Screenshots")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Where screenshots are saved, and what Super+F shows.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    SettingRow {
        title: I18n.t("Save to")
        hint: page.rejected ? I18n.t("Use a full path, like ~/Pictures") : I18n.t("Type a folder, then Enter. Empty uses the default.")
        warn: page.rejected

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: Theme.bgTray

            TextInput {
                id: folder

                Keys.onReturnPressed: page.rejected = !Settings.setShotFolder(text)
                Keys.onEnterPressed: page.rejected = !Settings.setShotFolder(text)
                onTextEdited: page.rejected = false

                onActiveFocusChanged: if (!activeFocus) {
                    page.rejected = false;
                    text = Qt.binding(() => Settings.tilde(Settings.shotDir));
                }

                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }

                verticalAlignment: TextInput.AlignVCenter
                text: Settings.tilde(Settings.shotDir)
                color: Theme.fg
                selectByMouse: true
                clip: true
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.medium

        Item {
            Layout.fillWidth: true
        }

        Action {
            onClicked: Gallery.toggle()

            icon: "photo_library"
            label: I18n.t("Open gallery")
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
