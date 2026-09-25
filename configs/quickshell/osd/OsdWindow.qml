pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

PanelWindow {
    id: win

    readonly property int segments: 16
    readonly property int filled: Math.round(Osd.value * win.segments)
    readonly property bool app: Osd.kind === "app"

    // Mapped until the fade ends.
    visible: Osd.shown || card.opacity > 0.01
    // No anchors: layer-shell centres it.
    WlrLayershell.namespace: "ummitos-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 208
    implicitHeight: 208
    color: "transparent"
    mask: Region {}

    Surface {
        id: card

        anchors.fill: parent
        radius: Theme.rounding.extraExtraLarge
        tone: Theme.bgAlt
        lift: 1.3

        opacity: Osd.shown ? 1 : 0
        scale: Osd.shown ? 1 : Theme.popScale

        // Same length as the scale, or the unmap cut it mid-animation.
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing.medium

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: Theme.icon.huge
                implicitHeight: Theme.icon.huge

                IconImage {
                    id: appIcon

                    anchors.fill: parent
                    source: Osd.icon
                    visible: win.app && appIcon.status === Image.Ready
                    opacity: Osd.muted ? 0.4 : 1
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !win.app || appIcon.status !== Image.Ready
                    text: {
                        if (Osd.kind === "brightness")
                            return Osd.value > 0.6 ? "brightness_high" : Osd.value > 0.25 ? "brightness_medium" : "brightness_low";
                        if (Osd.muted)
                            return "volume_off";
                        return Osd.value > 0.5 ? "volume_up" : Osd.value > 0 ? "volume_down" : "volume_mute";
                    }
                    color: Osd.muted ? Theme.dim : Theme.fg
                    fill: 1
                    size: Theme.icon.huge
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Osd.muted ? "Muted" : Math.round(Osd.value * 100) + "%"
                color: Osd.muted ? Theme.dim : Theme.fg
                font {
                    family: Theme.fontDisplay
                    pixelSize: Osd.muted ? Theme.fontSize.extraLarge : Theme.fontSize.huge
                    weight: Theme.weight.bold
                    // Tabular, or the square twitches as the digits change.
                    features: ({
                            tnum: 1
                        })
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing.hair

                Repeater {
                    model: win.segments

                    Rectangle {
                        required property int index

                        implicitWidth: 6
                        implicitHeight: 14
                        radius: Theme.rounding.extraSmall / 2
                        color: index < win.filled ? (Osd.muted ? Theme.dim : Theme.accentText) : Theme.bgTray

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.width - Theme.padding.extraLarge * 2
                horizontalAlignment: Text.AlignHCenter
                visible: win.app && Osd.label !== ""
                text: Osd.label
                color: Theme.dim
                elide: Text.ElideRight
                font {
                    family: Theme.font
                    pixelSize: Theme.fontSize.smaller
                    weight: Theme.weight.medium
                    letterSpacing: Theme.tracking.wider
                }
            }
        }
    }
}
