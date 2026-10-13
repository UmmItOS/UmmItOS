import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import ".."

// Widgets on the desktop: above the wallpaper, below every window.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // Under a window the card is not seen, so moving it would only be motion nobody asked for.
        readonly property bool seen: (Hyprland.monitorFor(modelData)?.activeWorkspace?.toplevels.values.length ?? 0) === 0
        // The notifications share this corner; the card steps below the toasts and beside the open panel.
        readonly property bool shared: win.seen && Notifs.toastScreen === (modelData?.name ?? "")
        readonly property real down: win.shared && Notifs.toastHeight > 0 ? Notifs.toastHeight + Theme.spacing.medium : 0
        // The card's own left edge, in screen x, before it moves.
        readonly property real cardLeft: (modelData?.width ?? Theme.fallbackScreen.width) - Theme.windowInset - card.implicitWidth
        // A bar dropdown over the card pushes it clear to the left; the open panel moves it by the panel's width.
        readonly property real left: {
            const f = win.seen && Notifs.flyout && Notifs.flyoutScreen === (modelData?.name ?? "") && Notifs.flyoutRight > win.cardLeft;
            // Far enough that the card's right edge clears the dropdown's left edge.
            const fromFlyout = f ? win.cardLeft + card.implicitWidth - Notifs.flyoutLeft + Theme.spacing.small : 0;
            return Math.max(fromFlyout, win.shared && Notifs.panelOpen ? Theme.notification.width : 0);
        }

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
        implicitWidth: (modelData?.width ?? Theme.fallbackScreen.width) - Theme.windowInset * 2
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

                x: -Math.min(win.left, win.cardLeft - Theme.windowInset)
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
