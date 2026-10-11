pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A joke: the grey "Activate" reminder another system leaves in the corner.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        property real shown: Settings.activateShow ? 1 : 0

        screen: modelData
        visible: shown > 0
        // Outside the ummitos-* layer rule, which would blur a rectangle behind the words.
        WlrLayershell.namespace: "activate-linux"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
            right: true
        }

        margins {
            bottom: Theme.windowInset + Theme.spacing.extraLarge
            right: Theme.windowInset + Theme.spacing.extraLarge
        }

        implicitWidth: words.implicitWidth
        implicitHeight: words.implicitHeight
        color: "transparent"
        // Clicks go to what is under it.
        mask: Region {}

        Behavior on shown {
            NumberAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }

        Column {
            id: words

            opacity: win.shown * Theme.activateOpacity
            layer.enabled: win.shown < 1

            layer.effect: MotionBlur {
                settled: win.shown
            }

            Text {
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: I18n.t("Activate Linux")
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.large
            }

            Text {
                anchors.right: parent.right
                textFormat: Text.PlainText
                text: I18n.t("Go to Settings to activate Linux.")
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
            }
        }
    }
}
