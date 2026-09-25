pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    readonly property var player: Players.active

    // No real length (browser tabs): show elapsed time only.
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
        spacing: Theme.spacing.extraLargeIncreased
        visible: root.player

        Item {
            id: disc

            readonly property int art: 170
            readonly property int gap: Theme.spacing.small
            readonly property int reach: 34
            readonly property int count: Cava.bars * 2

            Layout.alignment: Qt.AlignVCenter
            implicitWidth: disc.art + (disc.gap + disc.reach) * 2
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
                    // Not `art`: an id shadows disc's `art` property.
                    id: cover

                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 380
                    sourceSize.height: 380
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    text: "music_note"
                    color: Theme.dim
                    size: Theme.icon.extraLarge
                }
            }
        }

        ColumnLayout {
            // Never its natural width, or a long title pushes past the card.
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

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: parent.width
                Layout.topMargin: Theme.spacing.small
                spacing: Theme.spacing.small
                visible: Mpris.players.values.length > 1

                Repeater {
                    model: Mpris.players

                    Rectangle {
                        id: chip
                        required property MprisPlayer modelData

                        readonly property bool current: modelData === root.player

                        Layout.fillWidth: true
                        Layout.maximumWidth: implicitWidth
                        implicitWidth: chipLabel.implicitWidth + Theme.padding.large * 2
                        implicitHeight: 28
                        radius: Theme.rounding.full
                        color: current ? Theme.accent : Theme.bgAlt

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, chip.width - Theme.padding.large * 2)
                            elide: Text.ElideRight
                            text: chip.modelData.identity
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }

                        TapHandler {
                            onTapped: Players.chosen = chip.modelData
                        }
                    }
                }
            }
        }
    }
}
