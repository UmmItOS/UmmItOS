pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuUsage: 0      // 0-1
    property real cpuTemp: 0       // degrees C
    property real gpuTemp: 0
    property real memUsed: 0       // bytes
    property real memTotal: 1
    property real storageUsed: 0
    property real storageTotal: 1
    property int uptimeSeconds: 0
    property string distro: "Linux"

    readonly property real memRatio: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real storageRatio: storageTotal > 0 ? storageUsed / storageTotal : 0

    readonly property string uptimeText: {
        const h = Math.floor(uptimeSeconds / 3600);
        const m = Math.floor((uptimeSeconds % 3600) / 60);
        const d = Math.floor(h / 24);
        if (d > 0)
            return `up ${d} day${d === 1 ? "" : "s"}, ${h % 24} hour${h % 24 === 1 ? "" : "s"}`;
        if (h > 0)
            return `up ${h} hour${h === 1 ? "" : "s"}, ${m} minute${m === 1 ? "" : "s"}`;
        return `up ${m} minute${m === 1 ? "" : "s"}`;
    }

    function formatBytes(bytes: real): string {
        const gib = bytes / (1024 * 1024 * 1024);
        if (gib >= 1)
            return gib.toFixed(1) + "GiB";
        return (bytes / (1024 * 1024)).toFixed(0) + "MiB";
    }

    // `active` means a panel is on screen and wants live numbers. Nothing
    // else reads these, so with it off nothing is polled at all; turning it on
    // samples straight away, so the dashboard opens on real values.
    property bool active: false

    property real lastIdle: 0
    property real lastTotal: 0

    function refresh(): void {
        stat.reload();
        meminfo.reload();
        uptime.reload();
        temps.running = true;
        storage.running = true;
    }

    onActiveChanged: {
        if (active)
            refresh();
    }

    Timer {
        running: root.active
        interval: 2000
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            // cpu  user nice system idle iowait irq softirq steal
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            const dIdle = idle - root.lastIdle;
            const dTotal = total - root.lastTotal;
            if (root.lastTotal > 0 && dTotal > 0)
                root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
            root.lastIdle = idle;
            root.lastTotal = total;
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const kv = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    kv[m[1]] = Number(m[2]) * 1024;
            }
            root.memTotal = kv.MemTotal ?? 1;
            root.memUsed = (kv.MemTotal ?? 0) - (kv.MemAvailable ?? 0);
        }
    }

    FileView {
        id: uptime
        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = Math.floor(Number(text().split(" ")[0]))
    }

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]+)"?/m);
            if (m)
                root.distro = m[1];
        }
    }

    // hwmon indices shuffle between boots, so resolve the sensors by name.
    Process {
        id: temps
        command: ["sh", "-c", `for h in /sys/class/hwmon/hwmon*; do n=$(cat "$h/name" 2>/dev/null); case "$n" in k10temp|coretemp) printf 'cpu %s\\n' "$(cat "$h/temp1_input" 2>/dev/null)";; amdgpu|nouveau) printf 'gpu %s\\n' "$(cat "$h/temp1_input" 2>/dev/null)";; esac; done`]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const [which, milli] = line.split(" ");
                    if (!milli)
                        continue;
                    if (which === "cpu")
                        root.cpuTemp = Number(milli) / 1000;
                    else if (which === "gpu")
                        root.gpuTemp = Number(milli) / 1000;
                }
            }
        }
    }

    Process {
        id: storage
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\n").pop().trim().split(/\s+/);
                root.storageUsed = Number(parts[0]);
                root.storageTotal = Number(parts[1]);
            }
        }
    }
}
