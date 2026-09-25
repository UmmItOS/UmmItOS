import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Top layer, under fullscreen windows, so a game never trips it.
PanelWindow {
    id: root

    required property var modelData

    screen: modelData
    WlrLayershell.namespace: "hot-corner"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        left: true
    }
    implicitWidth: Theme.spacing.extraSmall - 1
    implicitHeight: implicitWidth
    color: "transparent"

    HoverHandler {
        id: hover
    }

    // Held briefly, so brushing past does not count.
    Timer {
        running: hover.hovered
        interval: Theme.duration.expressiveFastEffects - 70
        onTriggered: Switcher.overview(true)
    }
}
