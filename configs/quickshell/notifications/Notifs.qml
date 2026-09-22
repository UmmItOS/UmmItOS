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

    readonly property int cap: 60

    function record(notification: var): void {
        history.insert(0, {
            key: Date.now() + "-" + notification.id,
            appName: notification.appName,
            summary: notification.summary,
            body: safeBody(notification.body),
            image: notification.image,
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
