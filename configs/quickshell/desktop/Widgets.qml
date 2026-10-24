import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import ".."

// Widgets on the desktop: above the wallpaper, below every window. The weather and now-playing cards stack top-right in one column that dodges the notifications so neither overflows or is covered.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // Under a window the column is not seen, so moving it would only be motion nobody asked for.
        readonly property bool seen: (Hyprland.monitorFor(modelData)?.activeWorkspace?.toplevels.values.length ?? 0) === 0
        // The notifications share this corner; the column steps below the toasts and beside the open panel.
        readonly property bool shared: win.seen && Notifs.toastScreen === (modelData?.name ?? "")
        readonly property real down: win.shared && Notifs.toastHeight > 0 ? Notifs.toastHeight + Theme.spacing.medium : 0
        // The column's own left edge, in screen x, before it moves. Both cards are widgetWidth wide.
        readonly property real cardLeft: (modelData?.width ?? Theme.fallbackScreen.width) - Theme.windowInset - Theme.widgetWidth
        // A bar dropdown over the column pushes it clear to the left; the open panel moves it by the panel's width.
        readonly property real left: {
            const f = win.seen && Notifs.flyout && Notifs.flyoutScreen === (modelData?.name ?? "") && Notifs.flyoutRight > win.cardLeft;
            // Far enough that the column's right edge clears the dropdown's left edge.
            const fromFlyout = f ? win.cardLeft + Theme.widgetWidth - Notifs.flyoutLeft + Theme.spacing.small : 0;
            return Math.max(fromFlyout, win.shared && Notifs.panelOpen ? Theme.notification.width : 0);
        }

        screen: modelData
        // Stays mapped while a card fades out.
        visible: weather.opacity > 0 || media.opacity > 0
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

        // Room to move into, so the column slides by transform instead of resizing the surface.
        implicitWidth: (modelData?.width ?? Theme.fallbackScreen.width) - Theme.windowInset * 2
        implicitHeight: (modelData?.height ?? Theme.fallbackScreen.height) - Theme.barHeight - Theme.windowInset * 2
        color: "transparent"

        mask: Region {
            x: stack.x + shift.x
            y: stack.y + shift.y
            width: stack.width
            height: stack.height
        }

        Column {
            id: stack

            anchors.top: parent.top
            anchors.right: parent.right
            spacing: Theme.spacing.medium

            transform: Translate {
                id: shift

                x: -Math.min(win.left, win.cardLeft - Theme.windowInset)
                y: Math.min(win.down, win.height - stack.height)

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

            WeatherCard {
                id: weather

                anchors.right: parent.right
            }

            MediaCard {
                id: media

                anchors.right: parent.right
            }
        }
    }
}
