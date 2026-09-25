pragma ComponentBehavior: Bound

import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import ".."

GridView {
    id: grid

    cellWidth: width / 4
    cellHeight: 120
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
                ColorAnimation {
                    duration: Theme.duration.expressiveFastEffects
                }
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.padding.medium
                }
                spacing: Theme.spacing.extraSmall

                Text {
                    text: cell.modelData?.name ?? ""
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.large
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: {
                        const names = cell.modelData?.toplevels.values.map(t => t.title) ?? [];
                        return names.length === 0 ? "empty" : names.join("\n");
                    }
                    color: cell.modelData?.focused ? Theme.fg : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: cell.modelData?.activate()
            }
        }
    }
}
