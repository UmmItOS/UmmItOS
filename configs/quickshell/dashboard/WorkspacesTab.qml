pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

GridView {
    id: grid

    cellWidth: width / Theme.dashboard.workspaceColumns
    cellHeight: Theme.dashboard.workspaceCell
    clip: true
    model: [...Hyprland.workspaces.values].filter(w => w && w.id > 0)

    delegate: Item {
        id: cell

        required property HyprlandWorkspace modelData

        width: grid.cellWidth
        height: grid.cellHeight

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacing.small
            radius: Theme.rounding.large
            color: cell.modelData?.urgent ? Theme.urgent : cell.modelData?.focused ? Theme.accent : Theme.glass

            Behavior on color {
                FastColor {}
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.spacing.medium
                }

                spacing: Theme.spacing.extraSmall

                Text {
                    textFormat: Text.PlainText
                    text: cell.modelData?.name ?? ""
                    color: cell.modelData?.urgent ? Theme.fg : cell.modelData?.focused ? Theme.accentOn : Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    textFormat: Text.PlainText

                    text: {
                        const names = cell.modelData?.toplevels.values.map(t => t.title) ?? [];
                        return names.length === 0 ? "empty" : names.join("\n");
                    }

                    color: cell.modelData?.urgent ? Theme.fg : cell.modelData?.focused ? Theme.accentOn : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: Theme.dashboard.workspaceLines
                }
            }

            MouseArea {
                onClicked: cell.modelData?.activate()

                anchors.fill: parent
            }
        }
    }
}
