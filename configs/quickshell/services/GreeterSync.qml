import Quickshell
import QtQuick
import ".."

// Keeps the login screen's copy of the wallpaper and accent current; the greeter cannot read this home.
Scope {
    id: root

    readonly property string shared: "/var/lib/ummitos-greeter"

    function sync(): void {
        if (Wallpapers.actual === "")
            return;
        Quickshell.execDetached(["sh", "-c", '[ -w "$1" ] || exit 0; cp -f "$2" "$1/wallpaper" && printf "%s" "$3" > "$1/accent"', "sh", root.shared, Wallpapers.actual, Theme.accent.toString()]);
    }

    Connections {
        target: Wallpapers
        function onActualChanged(): void {
            root.sync();
        }
    }

    Connections {
        target: Theme
        function onAccentChanged(): void {
            root.sync();
        }
    }

    Component.onCompleted: root.sync()
}
