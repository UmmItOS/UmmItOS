pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    // Glyphs for apps that ask for an icon the theme does not have, where a
    // symbol in the bar's own style reads better than the app's logo.
    readonly property var glyphs: ({
            "Fcitx": "keyboard"
        })

    // The app's own icon, from its desktop entry, for a tray item that sent
    // nothing drawable. "ente_status_icon_1" → ente, then ente-desktop.
    function appIcon(id: string): string {
        const stem = id.replace(/_status_icon_\d+$/, "").toLowerCase();
        const apps = DesktopEntries.applications.values;
        const entry = apps.find(e => e.id === stem || e.id === stem + "-desktop") ?? apps.find(e => e.id.startsWith(stem));
        return entry ? Quickshell.iconPath(entry.icon, true) : "";
    }

    spacing: Theme.spacing.medium

    // An app registers its tray icon once, with whichever tray host is up.
    // When the shell restarts, some (Proton VPN, through libayatana) never
    // register again and vanish. Offer the new host every tray icon on the
    // bus that it does not already list.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", `
        sleep 1
        w="org.kde.StatusNotifierWatcher"
        reg=$(busctl --user get-property $w /StatusNotifierWatcher $w RegisteredStatusNotifierItems)
        for n in $(busctl --user list --no-legend | awk '{print $1}' | grep '^org.kde.StatusNotifierItem-'); do
            owner=$(busctl --user status "$n" | sed -n 's/^UniqueName=//p')
            case "$reg" in *"$n"*|*"\"$owner/"*) continue ;; esac
            busctl --user call $w /StatusNotifierWatcher $w RegisterStatusNotifierItem s "$n"
        done`])

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: entry
            required property SystemTrayItem modelData

            readonly property string source: modelData.icon
            // A theme icon the theme lacks (fcitx5 asks for
            // input-keyboard-symbolic, which Adwaita does not have), or a
            // pixmap that never arrived: Quickshell numbers each pixmap it
            // receives, and ente's Electron tray stays at 0. Both would draw
            // Qt's magenta checkerboard.
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
                // A chosen glyph stands for a real app; the question mark
                // stays dim because it stands for nothing.
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
