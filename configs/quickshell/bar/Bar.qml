import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property string home: Quickshell.env("HOME")

    WlrLayershell.namespace: "ummitos-bar"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 42
    color: "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.spacing.small
        radius: Theme.rounding.largeIncreased
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 14

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
            }

            BarButton {
                icon: "terminal"
                onClicked: Quickshell.execDetached(["kitty"])
            }

            BarButton {
                icon: "system_update_alt"
                onClicked: Quickshell.execDetached(["kitty", "--execute", bar.home + "/script/waybar/update.sh"])
            }

            BarButton {
                icon: "wallpaper"
                onClicked: Wallpapers.setRandom()
            }

            BarButton {
                icon: "grid_view"
                onClicked: Wallpapers.pickerOpen = !Wallpapers.pickerOpen
            }

            BarButton {
                icon: "keyboard"
                onClicked: Quickshell.execDetached(["kitty", "--execute", bar.home + "/script/hotkey-tui.sh"])
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Theme.spacing.small

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    text: "schedule"
                    color: Theme.accent
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm:ss")
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Tray {
                Layout.alignment: Qt.AlignVCenter
            }

            Volume {
                Layout.alignment: Qt.AlignVCenter
            }

            Battery {
                Layout.alignment: Qt.AlignVCenter
            }

            BarButton {
                icon: "power_settings_new"
                baseColor: Theme.accent
                onClicked: Quickshell.execDetached(["bash", bar.home + "/script/wlogout/blur-background.sh"])
            }
        }
    }
}
