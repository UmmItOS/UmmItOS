pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false

    // Mirrors configs/wlogout/layout, so the actions are the ones that were
    // already in use rather than a new set.
    readonly property var actions: [
        {
            id: "lock",
            icon: "lock",
            label: "Lock",
            key: "l",
            command: ["hyprlock"]
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
        if (!action)
            return;
        open = false;
        Quickshell.execDetached(action.command);
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
