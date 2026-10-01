import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// A window asking for attention on a workspace nobody is looking at gets a notice, not only a red dot.
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
            clients.running = true;
        }
    }

    // An event that came while the last read was finishing.
    function readAgain(): void {
        if (root.pending.length > 0)
            clients.running = true;
    }

    // Straight from Hyprland: Quickshell's class and workspace can be empty, and it has no shown special workspace.
    Process {
        id: clients

        command: ["sh", "-c", "printf '[%s,%s]' \"$(hyprctl -j clients)\" \"$(hyprctl -j monitors)\""]
        onExited: Qt.callLater(root.readAgain)
        stdout: StdioCollector {
            onStreamFinished: {
                const waiting = root.pending;
                root.pending = [];
                let list = [];
                let monitors = [];
                try {
                    [list, monitors] = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const shown = monitors.flatMap(m => [m.activeWorkspace?.id, m.specialWorkspace?.id]).filter(id => id);
                for (const address of waiting)
                    root.tell(list.find(c => c.address === address), shown);
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

    function tell(client: var, shown: var): void {
        if (!client)
            return;
        // Already on some screen: the window itself is where the user will look.
        if (client.focusHistoryID === 0 || shown.includes(client.workspace?.id))
            return;
        const now = Date.now();
        if (now - (root.told[client.address] ?? 0) < Theme.duration.urgentRepeat)
            return;
        root.told[client.address] = now;

        const cls = (client.class || client.initialClass || "").toLowerCase();
        const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
        const app = entry?.name || client.class || I18n.t("A window");
        if (root.spokeLately(cls, app))
            return;
        Quickshell.execDetached(["sh", "-c", 'a=$(notify-send -a "$1" -i "$2" -A focus="$3" -- "$4" "$5") && [ "$a" = focus ] && hyprctl dispatch "hl.dsp.focus({ window = \\"address:$6\\" })"',
            "sh", app, entry?.icon ?? "", I18n.t("Go there"), I18n.t("%1 wants your attention").arg(app), I18n.t("%1 · Workspace %2").replace(/%([12])/g, (_, n) => Notifs.asText(n === "1" ? client.title : client.workspace?.name ?? "?")), client.address]);
    }
}
