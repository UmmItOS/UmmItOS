pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// How long each accent has been on screen, so the picker can offer the colours actually lived with.
Singleton {
    id: root

    // "#rrggbb" to seconds, counted only while the desktop is shown and unlocked.
    property var seconds: ({})
    // False until the saved times are read, and forever if they cannot be: never write over history.
    property bool loaded: false
    readonly property bool counting: loaded && !Lock.locked
    // Longest first.
    readonly property var ranked: Object.keys(seconds).sort((a, b) => seconds[b] - seconds[a])

    // The colour being timed and since when; credited on every change, so a colour tried for a moment gets only that moment.
    property string current: ""
    property real since: 0

    function spoken(s: real): string {
        const minutes = Math.floor(s / 60), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24);
        if (days > 0)
            return days + "d" + (hours % 24 > 0 ? " " + hours % 24 + "h" : "");
        if (hours > 0)
            return hours + "h" + (minutes % 60 > 0 ? " " + minutes % 60 + "m" : "");
        return Math.max(1, minutes) + "m";
    }

    function credit(): void {
        const now = Date.now();
        if (current !== "" && since > 0) {
            // Capped, so a sleep that skipped the lock is not counted as use.
            const elapsed = Math.min(now - since, Theme.duration.accentTick * 2) / 1000;
            const next = Object.assign({}, seconds);
            next[current] = (next[current] ?? 0) + elapsed;
            seconds = next;
            file.setText(JSON.stringify(next));
        }
        current = counting ? Theme.accent.toString() : "";
        since = counting ? now : 0;
    }

    onCountingChanged: credit()

    Connections {
        target: Theme
        function onAccentChanged(): void {
            if (root.counting)
                root.credit();
        }
    }

    // Saves once a minute, so a crash or reload loses at most that.
    Timer {
        running: root.counting
        repeat: true
        interval: Theme.duration.accentTick
        onTriggered: root.credit()
    }

    FileView {
        id: file

        path: Quickshell.statePath("accent-time.json")
        printErrors: false
        blockWrites: false
        onLoaded: {
            let saved;
            try {
                saved = JSON.parse(text());
            } catch (e) {
                return;
            }
            if (!saved || typeof saved !== "object" || Array.isArray(saved))
                return;
            const clean = {};
            for (const k of Object.keys(saved))
                if (/^#[0-9a-f]{6}([0-9a-f]{2})?$/.test(k) && Number.isFinite(saved[k]) && saved[k] > 0)
                    clean[k] = saved[k];
            root.seconds = clean;
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }
}
