//@ pragma UseQApplication

import Quickshell
import "background"
import "cheatsheet"
import "dashboard"
import "bar"
import "launcher"
import "notifications"
import "osd"
import "services"
import "session"
import "switcher"

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

    CheatsheetWindow {}

    OsdWindow {}

    Notifications {}

    BatteryNotifier {}

    NotificationPanel {}
}
