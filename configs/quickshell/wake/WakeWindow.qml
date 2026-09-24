import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// One black sheet per screen, mapped only while Wake.dark is above 0. It
// takes no input, so a click during the fade reaches whatever is under it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        screen: modelData
        visible: Wake.dark > 0
        WlrLayershell.namespace: "ummitos-wake"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        mask: Region {}
        color: "transparent"

        WakeCurtain {
            anchors.fill: parent
            dark: Wake.dark
        }
    }
}
