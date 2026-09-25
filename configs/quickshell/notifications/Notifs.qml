pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Notification objects die when they expire, so the panel cannot hold them.
// What it holds is a plain record taken as each one arrives.
Singleton {
    id: root

    // A ListModel, not a JS array: reassigning an array resets the view, so
    // dismissing one card jumped the list to the top and reloaded every image.
    readonly property ListModel history: ListModel {}
    property bool dnd: false
    property bool panelOpen: false
    // The open bar dropdown, if any, and where it sits. A dropdown is an
    // xdg-popup, which Hyprland draws above every layer, so the toasts step
    // aside rather than be covered. Only the dropdown that set these clears
    // them, so switching straight from one to another cannot undo the new one.
    property var flyout: null
    property real flyoutLeft: 0
    property real flyoutRight: 0

    readonly property int cap: 60

    // Apps whose group is open in the panel; the rest show their newest only.
    property var expanded: ({})

    function toggleGroup(app: string): void {
        const next = Object.assign({}, expanded);
        next[app] = !next[app];
        expanded = next;
    }

    function record(notification: var): void {
        // Keep each app's notifications together, newest group first: the
        // panel groups them by section, which needs them contiguous.
        let first = -1, n = 0;
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).appName === notification.appName) {
                if (first < 0)
                    first = i;
                n++;
            }
        }
        if (first > 0)
            history.move(first, 0, n);
        history.insert(0, {
            key: Date.now() + "-" + notification.id,
            appName: notification.appName,
            summary: notification.summary,
            body: safeBody(notification.body),
            // Pixels sent inline (image://qsimage/…) live only as long as the
            // notification does; kept, they failed and warned on every redraw.
            // ponytail: history drops those previews; save them to the cache
            // if they are missed.
            image: notification.image.startsWith("image://qsimage/") ? "" : notification.image,
            appIcon: notification.appIcon,
            critical: notification.urgency === 2,
            time: Qt.formatDateTime(new Date(), "HH:mm")
        });
        if (history.count > cap)
            history.remove(cap, history.count - cap);
    }

    function forget(key: string): void {
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).key === key) {
                history.remove(i);
                return;
            }
        }
    }

    function clear(): void {
        history.clear();
    }

    // Bodies are markup from any sender. StyledText loads <img> sources,
    // remote ones included, so an image tag would tell its sender who read the
    // notification and when. The preview has its own, local, image field.
    function safeBody(body: string): string {
        return (body ?? "").replace(/<img\b[^>]*>/gi, "");
    }

    // Only web links: a body can carry file:// or any scheme with a handler.
    function openLink(link: string): void {
        if (/^https?:\/\//i.test(link))
            Qt.openUrlExternally(link);
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.panelOpen = !root.panelOpen;
        }

        function close(): void {
            root.panelOpen = false;
        }

        function clear(): void {
            root.clear();
        }

        function dnd(): void {
            root.dnd = !root.dnd;
        }
    }
}
