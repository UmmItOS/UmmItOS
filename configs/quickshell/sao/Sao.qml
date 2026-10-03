pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import ".."

// The SAO menu: a column of round buttons pulled down from the left edge, as in Sword Art Online.
Singleton {
    id: root

    property bool open: false
    // The screen it opened on: the one pulled from, or the focused one.
    property var screen: null
    property int selected: 0
    // The card beside the column ("profile" or "skills"), or "".
    property string card: ""
    // The Logout dialog is up; `choice` is its focused button, 0 for ○ and 1 for ×. × by default, so Enter never logs out by itself.
    property bool asking: false
    property int choice: 1
    // The agent skills, each {name, about}; read when the Skills card first opens.
    property var skills: []
    property bool scanning: false
    property bool scanFailed: false

    readonly property var items: [
        {
            id: "profile",
            icon: "person",
            label: "Profile"
        },
        {
            id: "party",
            icon: "group",
            label: "Party"
        },
        {
            id: "items",
            icon: "inventory_2",
            label: "Items"
        },
        {
            id: "message",
            icon: "mail",
            label: "Message"
        },
        {
            id: "skills",
            icon: "auto_awesome",
            label: "Skills"
        },
        {
            id: "option",
            icon: "settings",
            label: "Option"
        },
        {
            id: "logout",
            icon: "logout",
            label: "Logout"
        }
    ]

    property string pendingCard: ""

    // The menu leaves first, so the next surface (and the overview's picture) never shows it.
    property string next: ""

    function show(on: var): void {
        // Only while closed, so an open menu never jumps screens.
        if (!open)
            screen = on ?? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        open = true;
    }

    function toggle(): void {
        if (open)
            open = false;
        else
            show(null);
    }

    // Hovering a different button plays the tap sound, same as clicking one.
    function select(index: int): void {
        if (index === selected)
            return;
        selected = index;
        Sounds.play("sao-tap");
    }

    function pick(index: int): void {
        if (index < 0 || index >= items.length)
            return;
        asking = false;
        selected = index;
        Sounds.play("sao-tap");
        const id = items[index].id;
        if (id === "profile" || id === "skills") {
            if (id === "skills" && skills.length === 0 && !scanning) {
                scanFailed = false;
                scan.running = true;
            }
            if (card === id) {
                card = "";
            } else if (card !== "") {
                // One card swings shut before the other opens, rather than swapping in a frame.
                pendingCard = id;
                card = "";
                swap.restart();
            } else {
                card = id;
            }
        } else if (id === "logout") {
            card = "";
            choice = 1;
            asking = true;
        } else {
            leave(id);
        }
    }

    // ○ logs out, × goes back.
    function answer(): void {
        if (choice === 0)
            logout();
        else
            asking = false;
    }

    function leave(id: string): void {
        next = id;
        open = false;
        after.restart();
    }

    function logout(): void {
        asking = false;
        open = false;
        Quickshell.execDetached(Session.actions.find(a => a.id === "logout").command);
    }

    // Copies "/name", ready to paste into Claude Code; the clipboard watcher shows the copy pill.
    function copySkill(name: string): void {
        Quickshell.execDetached(["wl-copy", "--", "/" + name]);
    }

    onOpenChanged: {
        card = "";
        pendingCard = "";
        asking = false;
        if (open) {
            // A reopen must not let the last choice's surface open over the menu.
            after.stop();
            next = "";
            selected = 0;
            Sounds.play("sao-open");
        }
    }

    Timer {
        id: swap

        onTriggered: if (root.open && root.pendingCard !== "") {
            root.card = root.pendingCard;
            root.pendingCard = "";
        }

        interval: Theme.duration.expressiveFastSpatial
    }

    Timer {
        id: after

        onTriggered: {
            if (root.next === "party")
                Switcher.overview(false);
            else if (root.next === "items")
                Launcher.show("apps");
            else if (root.next === "message")
                Notifs.panelOpen = true;
            else if (root.next === "option")
                Settings.open = true;
            root.next = "";
        }

        interval: Theme.duration.expressiveFastSpatial + Theme.duration.small
    }

    Process {
        id: scan

        onRunningChanged: root.scanning = running
        onExited: code => root.scanFailed = code !== 0 && root.skills.length === 0

        command: ["sh", Quickshell.shellDir + "/sao/skills.sh"]

        stdout: StdioCollector {
            onStreamFinished: root.skills = text.split("\n").filter(l => l !== "").map(l => {
                const tab = l.indexOf("\t");
                return {
                    name: tab < 0 ? l : l.slice(0, tab),
                    about: tab < 0 ? "" : l.slice(tab + 1)
                };
            })
        }
    }

    IpcHandler {
        function toggle(): void {
            root.toggle();
        }

        function close(): void {
            root.open = false;
        }

        target: "sao"
    }
}
