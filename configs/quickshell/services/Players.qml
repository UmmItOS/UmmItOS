pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // The player picked from the dashboard's chips, kept while it exists.
    property var chosen: null

    // Picked, else playing, else any.
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

    // MPRIS position does not tick; tick only while shown.
    property bool watched: false

    Timer {
        running: root.watched && (root.active?.isPlaying ?? false)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.active.positionChanged()
    }
}
