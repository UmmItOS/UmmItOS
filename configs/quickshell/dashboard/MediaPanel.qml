pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    // The bar shows the same player, so the choice of which one lives in a
    // singleton rather than in both.
    readonly property var player: Players.active

    // Some players publish no mpris:length at all — a browser tab is one — and
    // quickshell then hands back the position as the length. That is what made
    // the bar sit full at "0:45 / 0:45", vanish while seeking and come back on
    // play. Without a real length there is nothing to draw a bar against, so
    // only the elapsed time is shown.
    readonly property bool timed: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0

    Text {
        anchors.centerIn: parent
        visible: !root.player
        text: "Nothing playing"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.larger
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing.large
        visible: root.player

        // The art inside a ring of bars that move with the music, mirrored
        // left and right so the low end sits at the top and bottom.
        Item {
            id: disc

            // Sized to leave the text room since the calendar joined the
            // clock card and this card lost width.
            readonly property int art: 124
            readonly property int gap: Theme.spacing.small
            readonly property int reach: 26
            readonly property int count: Cava.bars * 2

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: art + (gap + reach) * 2
            implicitHeight: implicitWidth

            Repeater {
                model: disc.count

                Rectangle {
                    id: bar

                    required property int index
                    // Right half runs top to bottom, left half mirrors it back.
                    readonly property real level: Cava.levels[index < Cava.bars ? index : disc.count - 1 - index] ?? 0

                    x: disc.width / 2 - width / 2
                    y: disc.height / 2 - disc.art / 2 - disc.gap - height
                    width: Theme.spacing.extraSmall
                    height: Theme.spacing.extraSmall + bar.level * disc.reach
                    radius: width / 2
                    color: Theme.accentText
                    opacity: Cava.running ? 1 : 0

                    transform: Rotation {
                        origin.x: bar.width / 2
                        origin.y: bar.height + disc.gap + disc.art / 2
                        angle: bar.index * 360 / disc.count
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }
                }
            }

            ClippingRectangle {
                anchors.centerIn: parent
                implicitWidth: disc.art
                implicitHeight: disc.art
                radius: width / 2
                color: Theme.bgAlt

                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 380
                    sourceSize.height: 380
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(root.player?.trackArtUrl ?? "")
                    text: "music_note"
                    color: Theme.dim
                    size: Theme.icon.extraLarge
                }
            }
        }

        ColumnLayout {
            // Takes what the disc leaves, never its own natural width: a long
            // title or the time row would otherwise push it past the card.
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.spacing.extraSmall

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.player?.trackTitle ?? ""
                color: Theme.accentText
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.large
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.player?.trackArtist ?? ""
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.player?.trackAlbum ?? ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                elide: Text.ElideRight
                visible: text !== ""
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.spacing.medium
                spacing: Theme.spacing.largeIncreased

                MaterialIcon {
                    text: "skip_previous"
                    color: (root.player?.canGoPrevious ?? false) ? Theme.fg : Theme.dim
                    size: Theme.icon.large

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.player.previous()
                    }
                }

                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: width / 2
                    color: Theme.accent

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                        color: Theme.fg
                        fill: 1
                        size: Theme.icon.large
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.player.togglePlaying()
                    }
                }

                MaterialIcon {
                    text: "skip_next"
                    color: (root.player?.canGoNext ?? false) ? Theme.fg : Theme.dim
                    size: Theme.icon.large

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.player.next()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.medium
                implicitHeight: 6
                radius: height / 2
                color: Theme.bgAlt
                visible: root.timed

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.player?.position ?? 0) / (root.player?.length || 1)))
                    height: parent.height
                    radius: height / 2
                    color: Theme.accentText
                }

                MouseArea {
                    id: seek

                    anchors.fill: parent
                    anchors.margins: -Theme.spacing.small
                    enabled: root.player?.canSeek ?? false
                    // Measured against the bar, not the enlarged hit area.
                    onClicked: event => root.player.position = Math.max(0, Math.min(1, seek.mapToItem(seek.parent, event.x, 0).x / seek.parent.width)) * root.player.length
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.player !== null

                Text {
                    // Centred when it is alone, so an untimed player reads as
                    // "here is the elapsed time" and not as a label that lost
                    // the thing it was labelling.
                    Layout.fillWidth: !root.timed
                    horizontalAlignment: root.timed ? Text.AlignLeft : Text.AlignHCenter
                    text: Players.timeText(root.player?.position ?? 0)
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.features: ({
                            tnum: 1
                        })
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    visible: root.timed
                    text: Players.timeText(root.player?.length ?? 0)
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.features: ({
                            tnum: 1
                        })
                }
            }

            // One chip per player, so you can switch source.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.spacing.small
                spacing: Theme.spacing.small
                visible: Mpris.players.values.length > 1

                Repeater {
                    model: Mpris.players

                    Rectangle {
                        id: chip
                        required property MprisPlayer modelData

                        readonly property bool current: modelData === root.player

                        implicitWidth: chipLabel.implicitWidth + Theme.padding.large * 2
                        implicitHeight: 28
                        radius: Theme.rounding.full
                        color: current ? Theme.accent : Theme.bgAlt

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: chip.modelData.identity
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }
                    }
                }
            }
        }
    }
}
