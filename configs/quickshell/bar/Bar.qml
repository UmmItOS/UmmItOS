pragma ComponentBehavior: Bound

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
    implicitHeight: Theme.barHeight
    color: Theme.bg

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    component Cluster: Rectangle {
        default property alias content: inner.data

        implicitWidth: inner.implicitWidth + Theme.padding.large * 2
        implicitHeight: Theme.bar.cluster
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
                Layout.alignment: Qt.AlignVCenter
                icon: "keyboard_double_arrow_right"
                // First in the pill, so it stays under the pointer while the tools unfold beside it; turns to point back once open.
                rotation: Toolbox.open ? 180 : 0
                onClicked: Toolbox.toggle()

                Behavior on rotation {
                    enabled: Toolbox.ready

                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasized
                    }
                }
            }

            // The tools fold away behind the toggle; the pill has to really shrink, so this one
            // holder animates its width, while the tools themselves slide, fade and sharpen.
            Item {
                id: fold

                property real progress: Toolbox.open ? 1 : 0

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: tools.implicitWidth * progress
                implicitHeight: tools.implicitHeight
                clip: true
                // Fully folded, the tools are gone, so nothing can be clicked through the fold.
                visible: progress > 0

                Behavior on progress {
                    enabled: Toolbox.ready

                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Toolbox.open ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                    }
                }

                RowLayout {
                    id: tools

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacing.large
                    opacity: fold.progress
                    layer.enabled: opacity < 1
                    layer.effect: MotionBlur {
                        settled: tools.opacity
                    }
                    transform: Translate {
                        // Out from behind the toggle, to its right.
                        x: -(1 - fold.progress) * Theme.spacing.extraLarge
                    }

                    BarButton {
                        icon: "terminal"
                        onClicked: Quickshell.execDetached(["kitty"])
                    }

                    BarButton {
                        icon: "system_update_alt"
                        onClicked: Quickshell.execDetached(["kitty", "--execute", bar.home + "/script/misc/update.sh"])
                    }

                    WallpaperShuffle {}

                    BarButton {
                        icon: "grid_view"
                        onClicked: Wallpapers.pickerOpen = !Wallpapers.pickerOpen
                    }

                    BarButton {
                        icon: "keyboard"
                        onClicked: Cheatsheet.open = !Cheatsheet.open
                    }

                    BarButton {
                        // A second of grim and zbar: the spinner says it heard the click.
                        icon: Scan.scanning ? "" : "qr_code_scanner"
                        onClicked: Scan.start(bar.screen)

                        Spinner {
                            anchors.centerIn: parent
                            visible: Scan.scanning
                        }
                    }

                    AccentPicker {}

                    WeatherPicker {}
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Cluster {
            Layout.alignment: Qt.AlignVCenter

            Tray {}

            Network {}

            Bluetooth {}

            BarButton {
                icon: Notifs.dnd ? "notifications_off" : Notifs.history.count > 0 ? "notifications_active" : "notifications"
                baseColor: Notifs.dnd ? Theme.dim : Theme.fg
                onClicked: Notifs.panelOpen = !Notifs.panelOpen
            }

            Volume {}

            Battery {}
        }

        BarButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "settings"
            onClicked: Settings.toggle()
        }

        BarButton {
            Layout.alignment: Qt.AlignVCenter
            icon: "power_settings_new"
            onClicked: Session.open = !Session.open
        }
    }

    // Beside the clock, so it never moves the centre or the clusters.
    RecordingPill {
        anchors.left: clockColumn.right
        anchors.leftMargin: Theme.spacing.large
        anchors.verticalCenter: parent.verticalCenter
    }

    // On the screen's centre line, not between spacers, so it never drifts.
    ColumnLayout {
        id: clockColumn

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: -Theme.spacing.hair

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            color: Theme.fg
            font {
                family: Theme.fontDisplay
                pixelSize: Theme.fontSize.larger
                bold: true
                features: ({
                    tnum: 1
                })
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: clock.date.toLocaleString(I18n.locale, I18n.t("ddd d MMM"))
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
                weight: Theme.weight.medium
                letterSpacing: Theme.tracking.wide
            }
        }

        TapHandler {
            onTapped: Dashboard.toggleTab(0)
        }
    }
}
