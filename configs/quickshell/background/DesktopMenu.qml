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
        signal triggered

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
}
