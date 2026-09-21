pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Notification objects die when they expire, so the panel cannot hold them.
// What it holds is a plain record taken as each one arrives.
Singleton {
    id: root

    property list<var> history: []
    property bool dnd: false
    property bool panelOpen: false

    readonly property int cap: 60

    function record(notification: var): void {
        history = [
            {
                key: Date.now() + "-" + notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                image: notification.image,
                appIcon: notification.appIcon,
                critical: notification.urgency === 2,
                time: Qt.formatDateTime(new Date(), "HH:mm")
            },
            ...history
        ].slice(0, cap);
    }

    function forget(key: string): void {
        history = history.filter(n => n.key !== key);
    }

    function clear(): void {
        history = [];
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
