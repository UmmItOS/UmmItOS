import Quickshell
import Quickshell.Hyprland
import QtQuick
import ".."

// A window asking for attention on a workspace nobody is looking at gets a notice (and the notice's chime),
// not only a red workspace dot.
Scope {
    id: root

    // Address → when it last got a notice, so an app that keeps asking is heard once.
    property var told: ({})

    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (event.name !== "urgent")
                return;
            const address = event.data.startsWith("0x") ? event.data : "0x" + event.data;
            // The toplevel list can trail the event by a moment.
            Qt.callLater(() => root.tell(address));
        }
    }

    function tell(address: string): void {
        const window = Hyprland.toplevels.values.find(w => w && ("0x" + w.address.replace(/^0x/, "")) === address);
        const workspace = window?.workspace;
        // Already on some screen: the window itself is where the user will look.
        if (!window || window.activated || workspace?.active)
            return;
        const now = Date.now();
        if (now - (told[address] ?? 0) < Theme.duration.urgentRepeat)
            return;
        told[address] = now;

        // lastIpcObject is only filled after a refresh; the Wayland side always knows the app id.
        const cls = window.wayland?.appId || window.lastIpcObject?.class || "";
        const entry = cls !== "" ? DesktopEntries.heuristicLookup(cls) : null;
        const app = entry?.name || cls || I18n.t("A window");
        Quickshell.execDetached(["sh", "-c", 'a=$(notify-send -a "$1" -i "$2" -A focus="$3" "$4" "$5") && [ "$a" = focus ] && hyprctl dispatch "hl.dsp.focus({ window = \\"address:$6\\" })"',
            "sh", app, entry?.icon ?? "", I18n.t("Go there"), I18n.t("%1 wants your attention").arg(app), I18n.t("%1 · Workspace %2").arg(window.title).arg(workspace?.name ?? "?"), address]);
    }
}
