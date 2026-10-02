pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Whether the bar's tool cluster is unfolded; one state for every screen, kept across restarts.
Singleton {
    id: root

    property bool open: false
    // Set once the saved state is in, so the first value does not animate.
    property bool ready: false

    function toggle(): void {
        open = !open;
        saved.setText(open ? "1\n" : "0\n");
    }

    FileView {
        id: saved

        path: Quickshell.statePath("toolbox.txt")
        printErrors: false
        blockWrites: false
        onLoaded: {
            root.open = text().trim() === "1";
            Qt.callLater(() => root.ready = true);
        }
        onLoadFailed: Qt.callLater(() => root.ready = true)
    }
}
