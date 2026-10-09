pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

BarButton {
    id: root

    property bool popupOpen: false
    property real now: Date.now()

    function ago(time: real): string {
        const minutes = Math.floor((root.now - time) / 60000);
        if (minutes < 1)
            return I18n.t("just now");
        if (minutes < 60)
            return I18n.t("%1 min ago").arg(minutes);
        if (minutes < 1440)
            return I18n.t("%1 h ago").arg(Math.floor(minutes / 60));
        return I18n.t("%1 d ago").arg(Math.floor(minutes / 1440));
    }

    function iconFor(glyph: string): string {
        return glyph === "+" ? "add" : glyph === "−" ? "delete" : glyph === "→" ? "drive_file_move" : "edit";
    }

    onClicked: popupOpen = !popupOpen

    visible: Settings.watchShow
    icon: "history"
    label: "File changes"

    Timer {
        onTriggered: root.now = Date.now()

        interval: Theme.duration.toast * 5
        running: root.popupOpen
        repeat: true
        triggeredOnStart: true
    }

    Flyout {
        onCloseRequested: root.popupOpen = false

        anchorItem: root
        visible: root.popupOpen
        title: I18n.t("File changes")
        toggleVisible: false

        FlyoutEmpty {
            visible: FileChanges.entries.length === 0
            icon: "history"
            text: I18n.t("No changes yet")
        }

        FlyoutList {
            id: list

            visible: FileChanges.entries.length > 0
            values: FileChanges.entries

            delegate: FlyoutRow {
                id: row

                required property var modelData
                readonly property string folder: modelData.path.slice(0, modelData.path.lastIndexOf("/"))

                width: list.width

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.spacing.medium
                        rightMargin: Theme.spacing.medium
                    }

                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: root.iconFor(row.modelData.glyph)
                        color: row.modelData.glyph === "−" ? Theme.urgent : row.modelData.glyph === "+" ? Theme.good : Theme.dim
                        size: Theme.icon.small
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: row.modelData.path.slice(row.modelData.path.lastIndexOf("/") + 1)
                            elide: Text.ElideMiddle
                            color: row.ink
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                        }

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: Settings.tilde(row.folder)
                            elide: Text.ElideLeft
                            color: row.inkDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: root.ago(row.modelData.time)
                        color: row.inkDim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }

                TapHandler {
                    onTapped: Quickshell.execDetached(["xdg-open", row.folder])
                }
            }
        }
    }
}
