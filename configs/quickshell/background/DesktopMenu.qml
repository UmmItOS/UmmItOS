pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// The desktop's right-click menu: a Flyout hung from the point that was clicked.
Flyout {
    id: root

    signal chosen(string what)

    implicitWidth: Theme.control.menu
    hug: true
    toggleVisible: false
    title: I18n.t("Desktop")

    component Entry: FlyoutRow {
        id: entry

        property string icon
        property string label
        // Set for a checkbox row: it shows the switch and stays open on a tap.
        property bool checkable: false
        property bool ticked: false
        signal triggered

        Accessible.role: entry.checkable ? Accessible.CheckBox : Accessible.MenuItem
        Accessible.name: entry.label
        Accessible.checkable: entry.checkable
        Accessible.checked: entry.ticked
        Layout.fillWidth: true
        scale: tap.pressed ? Theme.pressScale : 1

        Behavior on scale {
            PressAnim {}
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Theme.spacing.medium
                rightMargin: Theme.spacing.medium
            }

            spacing: Theme.spacing.medium

            MaterialIcon {
                visible: !entry.checkable
                text: entry.icon
                color: Theme.accentText
            }

            Text {
                Layout.fillWidth: true
                text: entry.label
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                elide: Text.ElideRight
            }

            // Not interactive: the row's tap flips it, so the click is not handled twice.
            Toggle {
                visible: entry.checkable
                enabled: false
                checked: entry.ticked
            }
        }

        TapHandler {
            id: tap

            onTapped: entry.triggered()
        }
    }

    Entry {
        onTriggered: root.chosen("displays")

        icon: "monitor"
        label: I18n.t("Displays…")
    }

    Entry {
        onTriggered: root.chosen("wallpaper")

        icon: "wallpaper"
        label: I18n.t("Wallpaper…")
    }

    Entry {
        onTriggered: root.chosen("settings")

        icon: "settings"
        label: I18n.t("Settings")
    }

    Text {
        Layout.topMargin: Theme.spacing.medium
        Layout.leftMargin: Theme.spacing.medium
        text: I18n.t("Show on desktop")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
    }

    Entry {
        onTriggered: Settings.setWeatherCard(!Settings.weatherShow)

        label: I18n.t("Weather card")
        checkable: true
        ticked: Settings.weatherShow
    }

    Entry {
        onTriggered: Settings.setMediaCard(!Settings.mediaShow)

        label: I18n.t("Now playing card")
        checkable: true
        ticked: Settings.mediaShow
    }

    Entry {
        onTriggered: Settings.setActivate(!Settings.activateShow)

        label: I18n.t("Activate Linux")
        checkable: true
        ticked: Settings.activateShow
    }

    Entry {
        onTriggered: Settings.setFps(!Settings.fpsShow)

        label: I18n.t("FPS counter")
        checkable: true
        ticked: Settings.fpsShow
    }
}
