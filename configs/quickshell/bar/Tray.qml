import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    spacing: 10

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: entry
            required property SystemTrayItem modelData

            implicitWidth: 18
            implicitHeight: 18
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            IconImage {
                id: icon
                anchors.fill: parent
                implicitSize: 18
                source: entry.modelData.icon
                visible: status === Image.Ready
            }

            // Apps whose icon name is missing from the current icon theme
            // (fcitx5 asks for input-keyboard-symbolic, which Adwaita lacks).
            Text {
                anchors.centerIn: parent
                visible: !icon.visible
                text: ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
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
