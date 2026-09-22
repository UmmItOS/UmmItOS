pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    spacing: Theme.spacing.medium

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: entry
            required property SystemTrayItem modelData

            implicitWidth: Theme.icon.tray
            implicitHeight: Theme.icon.tray
            Layout.alignment: Qt.AlignVCenter
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            IconImage {
                id: icon
                anchors.fill: parent
                implicitSize: Theme.icon.tray
                source: entry.modelData.icon
                visible: status === Image.Ready
            }

            // Apps whose icon name is missing from the current icon theme
            // (fcitx5 asks for input-keyboard-symbolic, which Adwaita lacks).
            MaterialIcon {
                anchors.centerIn: parent
                visible: !icon.visible
                text: "help_center"
                color: Theme.dim
                size: Theme.icon.small
            }

            onClicked: event => {
                if (event.button === Qt.RightButton && entry.modelData.hasMenu) {
                    menu.open();
                } else {
                    entry.modelData.activate();
                }
            }

            QsMenuAnchor {
                id: menu
                menu: entry.modelData.menu
                anchor.item: entry
            }
        }
    }
}
