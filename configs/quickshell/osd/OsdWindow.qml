pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import ".."

PanelWindow {
    id: win

    readonly property int segments: Theme.osd.segments
    // Volume fills against its limit, so 300% of 400% is not a full bar.
    readonly property int filled: Math.round(Osd.value / (Osd.kind === "volume" ? Audio.limit : 1) * win.segments)
    readonly property bool app: Osd.kind === "app"
    readonly property bool input: Osd.kind === "input"
    // An input card leaves quicker: it was only a glance.
    readonly property int leave: input && !Osd.shown ? Theme.duration.imeLeave : Theme.duration.expressiveFastSpatial

    // Anything past Latin (Han, kana, Hangul, bopomofo) draws in the CJK face, not a fallback Qt picks.
    function cjk(text: string): bool {
        return /[^\u0000-\u024f]/.test(text);
    }

    // Mapped until the fade ends.
    visible: Osd.shown || card.opacity > 0.01
    // No anchors: layer-shell centres it.
    WlrLayershell.namespace: "ummitos-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.osd.size
    implicitHeight: Theme.osd.size
    color: "transparent"
    mask: Region {}

    Surface {
        id: card

        anchors.fill: parent
        radius: Theme.rounding.extraExtraLarge
        tone: Theme.bgAlt
        lift: Theme.lift.osd

        opacity: Osd.shown ? 1 : 0
        layer.enabled: opacity < 1

        layer.effect: MotionBlur {
            settled: card.opacity
        }

        scale: Osd.shown ? 1 : Theme.popScale

        // Same length as the scale, or the unmap cut it mid-animation.
        Behavior on opacity {
            NumberAnimation {
                duration: win.leave
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.emphasizedDecel
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: win.leave
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
                    opacity: Osd.muted ? Theme.osd.mutedIcon : 1
                }

                // The input method's own label: A, 速, 倉. It pops in when the method changes.
                Text {
                    id: glyph

                    anchors.centerIn: parent
                    height: Theme.icon.huge
                    verticalAlignment: Text.AlignVCenter
                    visible: win.input && Osd.glyph !== ""
                    textFormat: Text.PlainText
                    text: Osd.glyph
                    color: Theme.fg

                    font {
                        family: win.cjk(Osd.glyph) ? Theme.fontCjk : Theme.fontDisplay
                        pixelSize: Theme.icon.huge
                        weight: Theme.weight.bold
                    }

                    transform: Scale {
                        id: glyphPop

                        origin.x: glyph.width / 2
                        origin.y: glyph.height / 2
                    }

                    ParallelAnimation {
                        id: pop

                        NumberAnimation {
                            target: glyphPop
                            properties: "xScale,yScale"
                            from: Theme.popScale
                            to: 1
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }

                        NumberAnimation {
                            targets: [glyph, inputName]
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    Connections {
                        function onInputSwitched(): void {
                            pop.restart();
                        }

                        target: Osd
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    // An input method with no label of its own shows a keyboard instead of a blank.
                    visible: win.input ? Osd.glyph === "" : !win.app || appIcon.status !== Image.Ready

                    text: {
                        if (win.input)
                            return "keyboard";
                        if (Osd.kind === "brightness")
                            return Osd.value > Theme.osd.brightnessHigh ? "brightness_high" : Osd.value > Theme.osd.brightnessMedium ? "brightness_medium" : "brightness_low";
                        if (Osd.muted)
                            return "volume_off";
                        return Osd.value > Theme.volume.high ? "volume_up" : Osd.value > 0 ? "volume_down" : "volume_mute";
                    }

                    color: Osd.muted ? Theme.dim : Theme.fg
                    fill: 1
                    size: Theme.icon.huge
                }
            }

            Text {
                id: inputName

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, card.width - Theme.spacing.extraLarge * 2)
                visible: win.input
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: I18n.t(Osd.inputName)
                color: Theme.fg

                font {
                    family: win.cjk(text) ? Theme.fontCjk : Theme.fontDisplay
                    pixelSize: Theme.fontSize.large
                    weight: Theme.weight.bold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !win.input
                text: Osd.muted ? I18n.t("Muted") : Math.round(Osd.value * 100) + "%"
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

            // One dot per method in fcitx's group; the accent pill slides to the one in use.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                // One method has nothing to switch between.
                visible: win.input && Osd.inputs.length > 1
                implicitWidth: dots.implicitWidth
                implicitHeight: Theme.osd.dot

                Row {
                    id: dots

                    spacing: Theme.spacing.medium

                    Repeater {
                        model: Osd.inputs.length

                        Rectangle {
                            implicitWidth: Theme.osd.dot
                            implicitHeight: Theme.osd.dot
                            radius: Theme.osd.dot / 2
                            color: Theme.dim
                        }
                    }
                }

                Rectangle {
                    width: Theme.osd.dotPill
                    height: Theme.osd.dot
                    radius: Theme.osd.dot / 2
                    color: Theme.accentText

                    transform: Translate {
                        x: Osd.inputIndex * (Theme.osd.dot + dots.spacing) - (Theme.osd.dotPill - Theme.osd.dot) / 2

                        // Only while on screen, the exit fade included: a focus change moves it unseen.
                        Behavior on x {
                            enabled: win.visible

                            NumberAnimation {
                                duration: Theme.duration.expressiveFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curve.emphasizedDecel
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !win.input
                spacing: Theme.spacing.hair

                Repeater {
                    model: win.segments

                    Rectangle {
                        required property int index

                        implicitWidth: Theme.osd.segmentWidth
                        implicitHeight: Theme.osd.segmentHeight
                        radius: Theme.rounding.extraSmall / 2
                        color: index < win.filled ? (Osd.muted ? Theme.dim : Theme.accentText) : Theme.bgTray

                        Behavior on color {
                            FastColor {}
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: card.width - Theme.spacing.extraLarge * 2
                horizontalAlignment: Text.AlignHCenter
                visible: win.app && Osd.label !== ""
                textFormat: Text.PlainText
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
