import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// A window asking for attention on a workspace nobody is looking at gets a notice (and the notice's chime),
// not only a red workspace dot.
Scope {
    id: root

    // Address → when it last got a notice; Hyprland sends a burst of urgent events for one request.
    property var told: ({})
    // Addresses waiting for the client list to be read.
    property var pending: []

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "urgent")
                return;
            const address = event.data.startsWith("0x") ? event.data : "0x" + event.data;
            if (!root.pending.includes(address))
                root.pending = root.pending.concat([address]);
            if (!clients.running)
                clients.running = true;
        }
    }

    // Straight from Hyprland: Quickshell's cached class and workspace can be empty for a window.
    Process {
        id: clients

        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const waiting = root.pending;
                root.pending = [];
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                for (const address of waiting)
                    root.tell(list.find(c => c.address === address));
            }
        }
    }

    // An app that has just sent its own notification (a chat message) needs no second one.
    function spokeLately(cls: string, app: string): bool {
        const since = Date.now() - Theme.duration.urgentQuiet;
        for (let i = 0; i < Notifs.history.count; i++) {
            const entry = Notifs.history.get(i);
            const name = (entry.appName ?? "").toLowerCase();
            // This watcher's own notices are filed under the app too.
            if (entry.summary === I18n.t("%1 wants your attention").arg(app))
                continue;
            if (Number(entry.key.split("-")[0]) >= since && name !== "" && (name.includes(cls) || cls.includes(name) || name === app.toLowerCase()))
                return true;
        }
        return false;
    }

    function tell(client: var): void {
        if (!client)
            return;
        const shown = Hyprland.monitors.values.map(m => m?.activeWorkspace?.id);
        // Already on some screen: the window itself is where the user will look.
        if (client.focusHistoryID === 0 || shown.includes(client.workspace?.id))
            return;
        const now = Date.now();
        if (now - (told[client.address] ?? 0) < Theme.duration.urgentRepeat)
            return;
        told[client.address] = now;

        const cls = (client.class || client.initialClass || "").toLowerCase();
        const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
        const app = entry?.name || client.class || I18n.t("A window");
        if (spokeLately(cls, app))
            return;
        Quickshell.execDetached(["sh", "-c", 'a=$(notify-send -a "$1" -i "$2" -A focus="$3" "$4" "$5") && [ "$a" = focus ] && hyprctl dispatch "hl.dsp.focus({ window = \\"address:$6\\" })"',
            "sh", app, entry?.icon ?? "", I18n.t("Go there"), I18n.t("%1 wants your attention").arg(app), I18n.t("%1 · Workspace %2").arg(client.title).arg(client.workspace?.name ?? "?"), client.address]);
    }
}
