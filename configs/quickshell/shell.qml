//@ pragma UseQApplication

import Quickshell
import "background"
import "dashboard"
import "bar"
import "launcher"
import "notifications"

ShellRoot {
    // One bar per connected screen. Plugging a monitor in adds one.
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Background {}

    WallpaperPicker {}

    LauncherWindow {}

    DashboardWindow {}

    Notifications {}
}
