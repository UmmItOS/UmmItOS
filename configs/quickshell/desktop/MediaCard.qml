pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// The desktop "now playing" card: a cover that swells with the beat over a breathing halo, live bars, a title that scrolls when it is too long, a progress line, and the controls on hover. Same width as the weather card, so they stack in one column.
Rectangle {
    id: card

    readonly property var player: Players.active
    readonly property bool playing: (player?.isPlaying ?? false) && Settings.mediaShow
    readonly property bool timed: (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0
    // The low bands, which carry the beat.
    readonly property real beat: ((Cava.levels[0] ?? 0) + (Cava.levels[1] ?? 0) + (Cava.levels[2] ?? 0)) / 3
    property bool counted: false

    // Counts itself while it shows, so Cava and the position tick only then.
    function sync(): void {
        const want = card.visible && card.playing;
        if (want === card.counted)
            return;
        card.counted = want;
        Players.cardViewers += want ? 1 : -1;
    }

    onVisibleChanged: sync()
    onPlayingChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (card.counted)
            Players.cardViewers -= 1;
    }

    implicitWidth: Theme.widgetWidth
    implicitHeight: body.implicitHeight + Theme.spacing.large * 2
    radius: Theme.rounding.extraLarge
    color: Theme.scrim(Theme.panelTint)
    visible: opacity > 0
    opacity: card.playing ? 1 : 0
    scale: card.playing ? 1 : Theme.popScale
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: card.opacity
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: card.playing ? Theme.curve.expressiveDefaultSpatial : Theme.curve.emphasizedAccel
        }
    }

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        id: body

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.spacing.large
        }

        spacing: Theme.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            // The cover, swelling with the beat over a halo that breathes out while it plays.
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Theme.media.art
                implicitHeight: Theme.media.art

                Rectangle {
                    id: halo

                    anchors.fill: parent
                    radius: Theme.rounding.large
                    color: Theme.accentText
                    opacity: 0

                    ParallelAnimation {
                        running: card.playing && card.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            target: halo
                            property: "scale"
                            from: 1
                            to: Theme.media.haloScale
                            duration: Theme.duration.glow
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }

                        NumberAnimation {
                            target: halo
                            property: "opacity"
                            from: Theme.pulse.haloOpacity
                            to: 0
                            duration: Theme.duration.glow
                        }
                    }
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Theme.rounding.large
                    color: Theme.bgAlt
                    scale: 1 + card.beat * Theme.media.beat

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.small
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.standard
                        }
                    }

                    Image {
                        id: cover

                        anchors.fill: parent
                        source: card.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Theme.media.art * 2
                        sourceSize.height: Theme.media.art * 2
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            FastFade {}
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "music_note"
                        color: Theme.dim
                        size: Theme.icon.large
                    }
                }
            }

            ColumnLayout {
                id: words

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                // A new track rises into place.
                transform: Translate {
                    id: rise
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: I18n.t("Now playing")
                    color: Theme.accentText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.weight: Theme.weight.medium
                    font.letterSpacing: Theme.tracking.wide
                }

                // A title too long for the card scrolls to its end and back, pausing at each.
                Item {
                    id: lane

                    Layout.fillWidth: true
                    implicitHeight: title.implicitHeight
                    clip: true

                    Text {
                        id: title

                        readonly property real overflow: Math.max(0, implicitWidth - lane.width)

                        textFormat: Text.PlainText
                        text: card.player?.trackTitle ?? ""
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                        font.weight: Theme.weight.medium

                        SequentialAnimation on x {
                            running: title.overflow > 0 && card.playing && card.visible
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: Theme.media.scrollPause
                            }

                            NumberAnimation {
                                from: 0
                                to: -title.overflow
                                duration: title.overflow / Theme.media.scrollSpeed * 1000
                                easing.type: Easing.InOutSine
                            }

                            PauseAnimation {
                                duration: Theme.media.scrollPause
                            }

                            NumberAnimation {
                                from: -title.overflow
                                to: 0
                                duration: title.overflow / Theme.media.scrollSpeed * 1000
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: card.player?.trackArtist ?? ""
                    visible: text !== ""
                    elide: Text.ElideRight
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                }

                Connections {
                    function onTrackTitleChanged(): void {
                        enter.restart();
                    }

                    target: card.player
                    ignoreUnknownSignals: true
                }

                ParallelAnimation {
                    id: enter

                    NumberAnimation {
                        target: rise
                        property: "y"
                        from: Theme.media.rise
                        to: 0
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }

                    NumberAnimation {
                        target: words
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }
            }

            // Live bars from the music; the controls take their place under the pointer.
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: controls.implicitWidth
                implicitHeight: Theme.media.barMax

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacing.hair
                    opacity: hover.hovered ? 0 : 1

                    Behavior on opacity {
                        FastFade {}
                    }

                    Repeater {
                        model: Theme.media.bars

                        Rectangle {
                            required property int index

                            anchors.bottom: parent.bottom
                            width: Theme.media.barWidth
                            // A square root lifts the quiet passages, so the bars never sit flat.
                            height: Theme.media.barMin + Math.sqrt(Cava.levels[Math.round(index * (Cava.bars - 1) / (Theme.media.bars - 1))] ?? 0) * (Theme.media.barMax - Theme.media.barMin)
                            radius: width / 2
                            color: Theme.accentText

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.duration.small
                                }
                            }
                        }
                    }
                }

                Row {
                    id: controls

                    anchors.centerIn: parent
                    spacing: Theme.spacing.small
                    opacity: hover.hovered ? 1 : 0
                    visible: opacity > 0

                    transform: Translate {
                        x: hover.hovered ? 0 : Theme.spacing.medium

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.duration.expressiveFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: hover.hovered ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                            }
                        }
                    }

                    Behavior on opacity {
                        FastFade {}
                    }

                    Repeater {
                        model: [
                            {
                                icon: "skip_previous",
                                act: () => card.player?.previous()
                            },
                            {
                                icon: "pause",
                                act: () => card.player?.togglePlaying()
                            },
                            {
                                icon: "skip_next",
                                act: () => card.player?.next()
                            }
                        ]

                        MaterialIcon {
                            id: button

                            required property var modelData

                            text: button.modelData.icon
                            color: tap.hovered ? Theme.accentText : Theme.fg
                            size: Theme.icon.normal
                            fill: 1
                            scale: tap.pressed ? Theme.pressScale : 1

                            Behavior on color {
                                FastColor {}
                            }

                            Behavior on scale {
                                PressAnim {}
                            }

                            MouseArea {
                                id: tap

                                readonly property bool hovered: containsMouse

                                onClicked: button.modelData.act()

                                anchors.fill: parent
                                anchors.margins: -Theme.spacing.extraSmall
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }

        // How far into the track, when the player says how long it is.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.media.progress
            radius: height / 2
            color: Theme.bgTray
            visible: card.timed

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, (card.player?.position ?? 0) / (card.player?.length || 1)))
                height: parent.height
                radius: height / 2
                color: Theme.accentText

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.duration.normal
                    }
                }
            }
        }
    }
}
