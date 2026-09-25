//@ pragma UseQApplication

import Quickshell
import QtQuick
import "background"
import "charging"
import "cheatsheet"
import "dashboard"
import "bar"
import "launcher"
import "lock"
import "notifications"
import "osd"
import "services"
import "screenshot"
import "session"
import "switcher"
import "toast"
import "wake"

ShellRoot {
    // One bar per connected screen. Plugging a monitor in adds one.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Background {}

    WallpaperPicker {}

    LauncherWindow {}

    ClipboardWindow {}

    DashboardWindow {}

    SessionWindow {}

    SwitcherWindow {}

    Variants {
        model: Quickshell.screens

        HotCorner {}
    }

    CheatsheetWindow {}

    ScreenshotWindow {}

    LockScreen {}

    OsdWindow {}

    Notifications {}

    // Plugging in plays the ripple.
    BatteryNotifier {
        onPluggedIn: ripple.play()
    }

    // Re-offer tray icons the new host lacks: some apps register only once.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c", `
        sleep 1
        w="org.kde.StatusNotifierWatcher"
        reg=$(busctl --user get-property $w /StatusNotifierWatcher $w RegisteredStatusNotifierItems)
        for n in $(busctl --user list --no-legend | awk '{print $1}' | grep '^org.kde.StatusNotifierItem-'); do
            owner=$(busctl --user status "$n" | sed -n 's/^UniqueName=//p')
            case "$reg" in *"$n"*|*"\"$owner/"*) continue ;; esac
            busctl --user call $w /StatusNotifierWatcher $w RegisterStatusNotifierItem s "$n"
        done`])

    // Wi-Fi and Bluetooth coming and going.
    ConnectionNotifier {}

    // A nudge once the last full upgrade is over a week old.
    UpdateReminder {}

    // The screen fading up from black after sleep.
    WakeWindow {}

    CopyToast {}

    ChargeRipple {
        id: ripple
    }

    NotificationPanel {}
}
