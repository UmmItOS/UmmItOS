pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Which player the shell is talking about. The bar and the dashboard's media
// tab have to agree, so the choice lives here rather than in both.
Singleton {
    id: root

    // The player picked from the dashboard's chips, kept while it exists.
    property var chosen: null

    // The picked one; otherwise whatever is playing; failing that, whatever
    // is open.
    readonly property var active: {
        const all = Mpris.players.values;
        if (root.chosen && all.includes(root.chosen))
            return root.chosen;
        return all.find(p => p.isPlaying) ?? all[0] ?? null;
    }

    function timeText(seconds: real): string {
        if (!seconds || seconds < 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Set while something shows the position. MPRIS position does not tick
    // on its own, and ticking it for a closed dashboard is a wakeup a second
    // for as long as music plays.
    property bool watched: false

    Timer {
        running: root.watched && (root.active?.isPlaying ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.active.positionChanged()
    }
}
