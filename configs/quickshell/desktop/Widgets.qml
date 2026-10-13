import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Widgets on the desktop: above the wallpaper, below every window.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // The notifications share this corner; the card steps below the toasts and beside the open panel.
        readonly property bool shared: Notifs.toastScreen === (modelData?.name ?? "")
        readonly property real down: win.shared && Notifs.toastHeight > 0 ? Notifs.toastHeight + Theme.spacing.medium : 0
        readonly property real left: win.shared && Notifs.panelOpen ? Theme.notification.width : 0

        screen: modelData
        // Stays mapped while the card fades out.
        visible: Weather.ready && (Settings.weatherShow || card.opacity > 0)
        WlrLayershell.namespace: "ummitos-widgets"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            right: true
        }

        margins {
            top: Theme.barHeight + Theme.windowInset
            right: Theme.windowInset
        }

        // Room to move into, so the card slides by transform instead of resizing the surface.
        implicitWidth: card.implicitWidth + Theme.notification.width
        implicitHeight: (modelData?.height ?? Theme.fallbackScreen.height) - Theme.barHeight - Theme.windowInset * 2
        color: "transparent"

        mask: Region {
            x: card.x + shift.x
            y: card.y + shift.y
            width: card.width
            height: card.height
        }

        WeatherCard {
            id: card

            anchors.top: parent.top
            anchors.right: parent.right

            transform: Translate {
                id: shift

                x: -win.left
                y: Math.min(win.down, win.height - card.height)

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }
            }
        }
    }
}
