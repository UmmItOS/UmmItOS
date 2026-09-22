pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// What is playing, in the bar. The dashboard's media tab is where you go to
// look at it; this is where you reach for the pause button without going
// anywhere. Both read the same player from Players.
RowLayout {
    id: root

    readonly property var player: Players.active

    spacing: Theme.spacing.medium

    // Album art, at a size where it reads as a colour more than a picture.
    ClippingRectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Theme.icon.normal
        implicitHeight: Theme.icon.normal
        radius: Theme.rounding.small
        color: Theme.bgAlt
        visible: art.status === Image.Ready

        Image {
            id: art

            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: Theme.icon.normal * 2
            sourceSize.height: Theme.icon.normal * 2
        }
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: art.status !== Image.Ready
        text: "music_note"
        color: Theme.accentText
        size: Theme.icon.small
    }

    // Capped, not filled: a long title must not be allowed to push the rest of
    // the bar around, and fillWidth in a bar row is contagious. The cap scales
    // with the screen so the pill cannot reach the centred clock on a small one.
    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Math.min(220, root.Window.width / 8)
        text: root.player?.trackTitle ?? ""
        color: Theme.fg
        elide: Text.ElideRight
        font {
            family: Theme.font
            pixelSize: Theme.fontSize.normal
            weight: Theme.weight.medium
        }
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "skip_previous"
        color: (root.player?.canGoPrevious ?? false) ? Theme.fg : Theme.dim
        size: Theme.icon.small

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.spacing.extraSmall
            onClicked: root.player.previous()
        }
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
        color: Theme.fg
        fill: 1
        size: Theme.icon.small

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.spacing.extraSmall
            onClicked: root.player.togglePlaying()
        }
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "skip_next"
        color: (root.player?.canGoNext ?? false) ? Theme.fg : Theme.dim
        size: Theme.icon.small

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.spacing.extraSmall
            onClicked: root.player.next()
        }
    }

    // The title is the way into the full controls.
    TapHandler {
        onTapped: Dashboard.toggle()
    }
}
