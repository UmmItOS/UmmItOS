pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Plain records: notification objects die when they expire.
Singleton {
    id: root

    // A ListModel: reassigning an array reset the view.
    readonly property ListModel history: ListModel {}
    property bool dnd: false
    property bool panelOpen: false
    // Dropdowns draw above every layer, so the toasts step aside.
    property var flyout: null
    property real flyoutLeft: 0
    property real flyoutRight: 0
    property string flyoutScreen: ""

    readonly property int cap: 60

    // Apps whose group is open in the panel; the rest show their newest only.
    property var expanded: ({})

    function toggleGroup(app: string): void {
        const next = Object.assign({}, expanded);
        next[app] = !next[app];
        expanded = next;
    }

    function record(notification: var): void {
        // The panel's sections need each app's entries contiguous.
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
            // ponytail: inline images die with the notification; drop, or cache if missed.
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

    // StyledText fetches remote <img> (even "< img"): only b, i, u, br and whole links showing their own host survive.
    function safeBody(body: string): string {
        return (body ?? "").slice(0, Theme.notification.bodyChars).replace(/<a href="(https?:\/\/[^"\s<>@\/]*(?:\/[^"\s<>]*)?)">[\s\S]*?<\/a>|<[^>]*>?/gi, (tag, href) => href ? '<a href="' + href + '">' + href + '</a>' : /^(<\/?[biu]>|<br\s*\/?>)$/i.test(tag) ? tag : tag.replace(/</g, "&lt;"));
    }

    // A theme icon name, or a file under /usr/share: opening a sender's FIFO would hang the shell.
    function iconFor(name: string): string {
        if (!name || name.startsWith("/") && (!name.startsWith("/usr/share/") || name.includes("..")) || name.includes("://"))
            return "";
        return Quickshell.iconPath(name, true);
    }

    // For a body the shell sends itself: a window title or device name is text, not markup.
    function asText(text: string): string {
        return (text ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
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
