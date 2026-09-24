import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// One sheet per screen drawing the wake over the desktop, with the picture
// taken before sleep as its haze. It takes no input, so a click during the
// wake reaches whatever is under it.
//
// Its namespace is deliberately outside Hyprland's `ummitos-.*` rule: that
// rule blurs (and, with blur brightness, darkens) whatever a surface covers
// until its alpha falls below 0.1, then stops at once, so the end of the
// fade jumped. The wake draws its own blur. The same rule's no_anim is not
// needed: the sheet stays mapped (transparent when idle, like the toasts),
// so Hyprland never animates it in or out.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        screen: modelData
        visible: true
        WlrLayershell.namespace: "wake-curtain"
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
            picture: Wake.shot > 0 ? Wake.shotOf(win.modelData.name) : ""
        }
    }
}
