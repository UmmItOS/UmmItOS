pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Warns about one process that keeps the CPU or GPU busy; never kills it. Polls always (a monitor),
// unlike SysInfo, which polls only while something on screen shows it.
Singleton {
    id: root

    readonly property bool enabled: Settings.hogWarn

    property var hogs: []
    readonly property var top: hogs[0] ?? null

    // pid -> { streak }
    property var seen: ({})

    function update(lines: var): void {
        const next = {};
        const list = [];
        for (const line of lines) {
            const [pid, cpu, gpu, name] = line.split("\t");
            // The compositor draws everything else's frames, so its GPU time is never the culprit.
            if (name === "Hyprland")
                continue;
            const c = Number(cpu), g = Number(gpu);
            const kind = g >= Theme.hog.gpu && g >= c ? "GPU" : c >= Theme.hog.cpu ? "CPU" : "";
            if (kind === "")
                continue;
            const old = seen[pid] ?? {
                streak: 0
            };
            const rec = {
                streak: old.streak + 1
            };
            next[pid] = rec;
            if (rec.streak < Theme.hog.samples)
                continue;
            const share = kind === "GPU" ? g : c;
            list.push({
                pid: Number(pid),
                name: name,
                cpu: c,
                gpu: g,
                kind: kind,
                share: share
            });
        }
        seen = next;
        list.sort((a, b) => b.share - a.share);
        hogs = list;
    }

    onEnabledChanged: if (!enabled) {
        seen = {};
        hogs = [];
    }

    Timer {
        onTriggered: sampler.running = true

        interval: Theme.duration.hogPoll
        running: Settings.hogWarn && !sampler.running
        repeat: true
        triggeredOnStart: true
    }

    Process {
        id: sampler

        command: [Quickshell.env("HOME") + "/script/misc/proc-hogs.sh"]
        stdout: StdioCollector {
            onStreamFinished: root.update(text.split("\n").filter(l => l !== ""))
        }
    }
}
