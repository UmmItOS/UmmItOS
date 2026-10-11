pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// The battery screen: what used the battery and why, read from the logger's SQLite table.
Singleton {
    id: root

    property bool open: false
    // "unplug", "day", "week" or "all".
    property string range: "unplug"
    property bool loading: false
    // [{app, cpu, wh, est}], by Wh then CPU.
    property var apps: []
    // {batt_min, ac_min, bright, cpu, wifi_min, bt_min, batt_wh, batt_w}
    property var why: ({})
    // {n, wh, secs}
    property var sleep: ({})
    // [{profile, mins}]
    property var profiles: []
    // [{t, wh}], downsampled.
    property var curve: []

    readonly property string db: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/ummitos/battery.db"

    function toggle(): void {
        open = !open;
    }

    onOpenChanged: if (open)
        refresh()
    onRangeChanged: if (open)
        refresh()

    function refresh(): void {
        const now = Math.floor(Date.now() / 1000);
        // "Since unplug" is the last battery stretch: from the last plugged-in minute before the latest battery one.
        const from = range === "unplug" ? "(SELECT coalesce(max(t), 0) FROM samples WHERE plugged = 1 AND t < (SELECT coalesce(max(t), 0) FROM samples WHERE plugged = 0))" : range === "day" ? String(now - 86400) : range === "week" ? String(now - 7 * 86400) : "0";
        // Plugged-in minutes have no measured draw, so a fit of the battery minutes (watts = a + b * cpu) estimates them, once there is an hour of it.
        const sql = `CREATE TEMP VIEW f AS SELECT count(*) n, avg(watts) aw, avg(cpu) ac,
  coalesce((avg(watts * cpu) - avg(watts) * avg(cpu)) / nullif(avg(cpu * cpu) - avg(cpu) * avg(cpu), 0), 0) b
  FROM samples WHERE plugged = 0 AND watts > 0 AND cpu IS NOT NULL;
CREATE TEMP VIEW s AS SELECT t, plugged, CASE WHEN plugged = 0 AND watts > 0 THEN watts
  WHEN (SELECT n FROM f) >= 60 THEN max(0, (SELECT aw - b * ac FROM f) + (SELECT b FROM f) * coalesce(cpu, 0)) END w
  FROM samples WHERE t >= ${from};
SELECT u.app, round(sum(u.cpu_s), 1) cpu, round(sum(s.w / 60.0 * u.cpu_s / k.c), 3) wh, max(s.plugged) est
  FROM usage u JOIN s USING (t) JOIN (SELECT t, sum(cpu_s) c FROM usage GROUP BY t) k USING (t)
  GROUP BY u.app ORDER BY wh DESC, cpu DESC LIMIT 12;
.print @@
SELECT total(plugged = 0) batt_min, total(plugged = 1) ac_min, round(avg(brightness)) bright, round(avg(cpu) * 100, 1) cpu,
  total(wifi) wifi_min, total(bt) bt_min, round(total(CASE WHEN plugged = 0 AND watts > 0 THEN watts END) / 60.0, 2) batt_wh,
  round(avg(CASE WHEN plugged = 0 AND watts > 0 THEN watts END), 1) batt_w FROM samples WHERE t >= ${from};
.print @@
SELECT count(*) n, round(total(wh), 2) wh, total(end - start) secs FROM sleeps WHERE start >= ${from};
.print @@
SELECT profile, count(*) mins FROM samples WHERE t >= ${from} GROUP BY profile ORDER BY mins DESC;
.print @@
SELECT min(t) t, round(avg(energy_wh), 3) wh FROM samples WHERE t >= ${from}
  GROUP BY t / max(60, (${now} - max(${from}, (SELECT min(t) FROM samples))) / 120) ORDER BY t;`;
        loading = true;
        query.command = ["sqlite3", "-cmd", ".timeout 5000", "-cmd", ".mode json", root.db, sql];
        query.running = true;
    }

    Process {
        id: query

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("@@\n").map(p => {
                    try {
                        return JSON.parse(p.trim() || "[]");
                    } catch (e) {
                        return [];
                    }
                });
                root.apps = parts[0] ?? [];
                root.why = (parts[1] ?? [])[0] ?? ({});
                root.sleep = (parts[2] ?? [])[0] ?? ({});
                root.profiles = parts[3] ?? [];
                root.curve = parts[4] ?? [];
                root.loading = false;
            }
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.open = false;
        }
    }
}
