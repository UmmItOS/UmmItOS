pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Which player the shell is talking about. The bar and the dashboard's media
// tab have to agree, so the choice lives here rather than in both.
Singleton {
    id: root

    // Whatever is playing; failing that, whatever is open.
    readonly property var active: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? all[0] ?? null;
    }

    function timeText(seconds: real): string {
        if (!seconds || seconds < 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // MPRIS position does not tick on its own.
    Timer {
        running: root.active?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.active.positionChanged()
    }
}
