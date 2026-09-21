import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import ".."

// Three clusters, not one stream: identity on the left, the clock as the
// typographic anchor, status on the right. Grouping is carried by elevation
// and space; nothing is outlined.
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
    implicitHeight: Theme.barHeight
    color: Theme.bg

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // A rounded, slightly raised group. Used for the two icon clusters so they
    // read as one object each rather than four loose glyphs.
    component Cluster: Rectangle {
        default property alias content: inner.data

        implicitWidth: inner.implicitWidth + Theme.padding.large * 2
        implicitHeight: 32
        radius: Theme.rounding.full
        color: "transparent"

        Surface {
            anchors.fill: parent
            radius: parent.radius
            tone: Theme.bgTray
        }

        RowLayout {
            id: inner
            anchors.centerIn: parent
            spacing: Theme.spacing.large
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padding.large
        anchors.rightMargin: Theme.padding.large
        spacing: Theme.spacing.large

        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        Bandwidth {
            Layout.alignment: Qt.AlignVCenter
        }

        Cluster {
            Layout.alignment: Qt.AlignVCenter

            BarButton {
                icon: "terminal"
                onClicked: Quickshell.execDetached(["kitty"])
            }

            BarButton {
                icon: "system_update_alt"
                onClicked: Quickshell.execDetached(["kitty", "--execute", bar.home + "/script/misc/update.sh"])
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
        }

        Item {
            Layout.fillWidth: true
        }

        // The anchor. A clock does not need an icon telling you it is a clock.
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: -2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.larger
                font.bold: true
                font.features: ({
                        tnum: 1
                    })
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
            }

            TapHandler {
                onTapped: Dashboard.toggle()
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Cluster {
            Layout.alignment: Qt.AlignVCenter

            Tray {}

            Network {}

            BarButton {
                icon: Notifs.dnd ? "notifications_off" : Notifs.history.length > 0 ? "notifications_active" : "notifications"
                baseColor: Notifs.dnd ? Theme.dim : Theme.fg
                onClicked: Notifs.panelOpen = !Notifs.panelOpen
            }

            Volume {}

            Battery {}
        }

        BarButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "power_settings_new"
            baseColor: Theme.accentText
            onClicked: Session.open = !Session.open
        }
    }
}
