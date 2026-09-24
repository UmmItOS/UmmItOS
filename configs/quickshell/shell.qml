//@ pragma UseQApplication

import Quickshell
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

    // Wi-Fi and Bluetooth coming and going.
    ConnectionNotifier {}

    // A nudge once the last full upgrade is over a week old.
    UpdateReminder {}

    CopyToast {}

    ChargeRipple {
        id: ripple
    }

    NotificationPanel {}
}
