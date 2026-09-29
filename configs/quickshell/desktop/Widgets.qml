import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Widgets on the desktop: above the wallpaper, below every window.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Weather.ready
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
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        color: "transparent"

        WeatherCard {
            id: card
        }
    }
}
