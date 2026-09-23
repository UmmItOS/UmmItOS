import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// The top-left corner of a screen, GNOME-style: push the pointer into it and
// every workspace is shown. A few pixels wide and invisible. It sits on the
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

    // Held for a moment, so brushing past on the way to the bar does not
    // count; one opening per visit.
    Timer {
        running: hover.hovered
        interval: Theme.duration.expressiveFastEffects - 70
        onTriggered: Switcher.overview()
    }
}
