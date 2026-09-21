pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// A square that appears where you are already looking, says one number, and
// leaves. Segmented rather than continuous: at a glance you read the count of
// filled blocks, which is faster than judging the length of a bar.
PanelWindow {
    id: win

    readonly property int segments: 16
    readonly property int filled: Math.round(Osd.value * segments)

    // Stay mapped until the fade finishes, or the card vanishes instantly
    // instead of animating out.
    visible: Osd.shown || card.opacity > 0.01
    // No anchors: layer-shell centres the surface, which is where a transient
    // readout belongs.
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
        scale: Osd.shown ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }

        // The number is what gets read, so it is the anchor; the icon says
        // which control you are holding and the segments give the shape of it.
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing.medium

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    if (Osd.kind === "brightness")
                        return Osd.value > 0.6 ? "brightness_high" : Osd.value > 0.25 ? "brightness_medium" : "brightness_low";
                    if (Osd.muted)
                        return "volume_off";
                    return Osd.value > 0.5 ? "volume_up" : Osd.value > 0 ? "volume_down" : "volume_mute";
                }
                color: Osd.muted ? Theme.dim : Theme.fg
                fill: 1
                size: 52
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Osd.muted ? "Muted" : Math.round(Osd.value * 100) + "%"
                color: Osd.muted ? Theme.dim : Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Osd.muted ? 26 : 38
                font.weight: Theme.weight.bold
                // Tabular, or the square twitches as the digits change.
                font.features: ({
                        tnum: 1
                    })
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 3

                Repeater {
                    model: win.segments

                    Rectangle {
                        required property int index

                        implicitWidth: 6
                        implicitHeight: 10
                        radius: 1.5
                        color: index < win.filled ? (Osd.muted ? Theme.dim : Theme.accentText) : Theme.bgTray

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }
                    }
                }
            }
        }
    }
}
