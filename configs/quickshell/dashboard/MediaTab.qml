pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? all[0] ?? null;
    }

    function timeText(seconds: real): string {
        if (!seconds || seconds < 0)
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // MPRIS position does not tick on its own.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

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

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 190
            implicitHeight: 190
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
                size: 64
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
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
                    size: Theme.fontSize.extraLarge

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
                        size: Theme.fontSize.extraLarge
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.player.togglePlaying()
                    }
                }

                MaterialIcon {
                    text: "skip_next"
                    color: (root.player?.canGoNext ?? false) ? Theme.fg : Theme.dim
                    size: Theme.fontSize.extraLarge

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
                visible: root.player?.lengthSupported ?? false

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.player?.position ?? 0) / (root.player?.length || 1)))
                    height: parent.height
                    radius: height / 2
                    color: Theme.accentText
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    enabled: root.player?.canSeek ?? false
                    onClicked: event => root.player.position = (event.x / width) * root.player.length
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.player?.lengthSupported ?? false

                Text {
                    text: root.timeText(root.player?.position ?? 0)
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
                    text: root.timeText(root.player?.length ?? 0)
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
