pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool open: false

    readonly property var actions: [
        {
            id: "lock",
            icon: "lock",
            label: "Lock",
            key: "l",
            // No command: run() locks directly, once the menu has faded.
            command: null
        },
        {
            id: "suspend",
            icon: "bedtime",
            label: "Suspend",
            key: "s",
            command: ["systemctl", "suspend"]
        },
        {
            id: "hibernate",
            icon: "dark_mode",
            label: "Hibernate",
            key: "h",
            command: ["systemctl", "hibernate"]
        },
        {
            id: "logout",
            icon: "logout",
            label: "Log out",
            key: "e",
            command: ["hyprctl", "dispatch", "exit", "1"]
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Reboot",
            key: "r",
            command: ["systemctl", "reboot"]
        },
        {
            id: "shutdown",
            icon: "power_settings_new",
            label: "Shut down",
            key: "p",
            command: ["systemctl", "poweroff"]
        }
    ]

    function run(index: int): void {
        const action = actions[index];
        // A closing menu still sits under the pointer for its exit; a second
        // click must not run the action again.
        if (!action || !open)
            return;
        open = false;
        if (action.command)
            Quickshell.execDetached(action.command);
        else
            lockLater.restart();
    }

    // After the menu has faded, so it is not in the picture the lock fades
    // in from.
    Timer {
        id: lockLater
        interval: 400
        onTriggered: Lock.lock()
    }

    function indexForKey(key: string): int {
        return actions.findIndex(a => a.key === key.toLowerCase());
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            root.open = !root.open;
        }

        function close(): void {
            root.open = false;
        }
    }
}
