pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property var glyphs: ({
            "Fcitx": "keyboard"
        })

    // "ente_status_icon_1" → ente, then ente-desktop.
    function appIcon(id: string): string {
        const stem = id.replace(/_status_icon_\d+$/, "").toLowerCase();
        const apps = DesktopEntries.applications.values;
        const entry = apps.find(e => e.id === stem || e.id === stem + "-desktop") ?? apps.find(e => e.id.startsWith(stem));
        return entry ? Quickshell.iconPath(entry.icon, true) : "";
    }

    spacing: Theme.spacing.medium

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: entry
            required property SystemTrayItem modelData

            readonly property string source: modelData.icon
            // A theme icon the theme lacks, or a pixmap that never came (…/0).
            readonly property bool missing: {
                const themed = source.match(/^image:\/\/icon\/([^/].*)$/);
                if (themed)
                    return Quickshell.iconPath(themed[1], true) === "";
                return /^image:\/\/qspixmap\/.*\/0$/.test(source);
            }
            readonly property string glyph: root.glyphs[modelData.id] ?? ""
            readonly property string fallback: missing && glyph === "" ? root.appIcon(modelData.id) : ""

            implicitWidth: Theme.icon.tray
            implicitHeight: Theme.icon.tray
            Layout.alignment: Qt.AlignVCenter
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            IconImage {
                id: icon
                anchors.fill: parent
                implicitSize: Theme.icon.tray
                source: entry.missing ? entry.fallback : entry.source
                visible: source !== "" && status === Image.Ready
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !icon.visible
                text: entry.glyph || "help_center"
                color: entry.glyph ? Theme.fg : Theme.dim
                size: Theme.icon.small
            }

            property bool menuOpen: false

            onClicked: event => {
                if (event.button === Qt.RightButton && entry.modelData.hasMenu) {
                    entry.menuOpen = !entry.menuOpen;
                } else {
                    entry.modelData.activate();
                }
            }

            TrayMenu {
                anchorItem: entry
                menu: entry.modelData.menu
                title: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id.replace(/_status_icon_\d+$/, "")
                visible: entry.menuOpen
                onCloseRequested: entry.menuOpen = false
                onDone: entry.menuOpen = false
            }
        }
    }
}
