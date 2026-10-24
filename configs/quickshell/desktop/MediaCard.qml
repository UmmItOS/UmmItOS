pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// A "now playing" badge on the desktop: cover, title, artist. Same width as the weather card, so they stack in one column. Fades in while music plays.
Rectangle {
    id: card

    readonly property var player: Players.active
    readonly property bool playing: (player?.isPlaying ?? false) && Settings.mediaShow

    implicitWidth: Theme.widgetWidth
    implicitHeight: body.implicitHeight + Theme.spacing.large * 2
    radius: Theme.rounding.extraLarge
    color: Theme.scrim(Theme.panelTint)
    visible: opacity > 0
    opacity: card.playing ? 1 : 0
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: card.opacity
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }

    RowLayout {
        id: body

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            margins: Theme.spacing.large
        }

        spacing: Theme.spacing.medium

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Theme.icon.huge
            implicitHeight: Theme.icon.huge
            radius: Theme.rounding.large
            color: Theme.bgAlt

            Image {
                anchors.fill: parent
                source: card.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Theme.icon.huge * 2
                sourceSize.height: Theme.icon.huge * 2
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: !card.player?.trackArtUrl
                text: "music_note"
                color: Theme.dim
                size: Theme.icon.normal
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

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

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: card.player?.trackTitle ?? ""
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                font.weight: Theme.weight.medium
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
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: "equalizer"
            color: Theme.accentText
            size: Theme.icon.normal
            fill: 1
        }
    }
}
