pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import ".."

Item {
    id: root

    readonly property var player: Players.active
    readonly property int art: Theme.bar.mediaArt
    readonly property int count: Theme.bar.mediaBars * 2

    property bool counted: false

    function sync(): void {
        if (root.visible === root.counted)
            return;
        root.counted = root.visible;
        Players.barViewers += root.counted ? 1 : -1;
    }

    onVisibleChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (root.counted)
            Players.barViewers -= 1;
    }

    implicitWidth: art + (Theme.bar.mediaGap + Theme.bar.mediaReach) * 2
    implicitHeight: implicitWidth
    visible: opacity > 0
    opacity: root.player ? 1 : 0
    scale: tap.pressed ? Theme.pressScale : 1
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: root.opacity
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.player?.trackTitle ?? ""

    Behavior on opacity {
        FastFade {}
    }

    Behavior on scale {
        PressAnim {}
    }

    Repeater {
        model: root.count

        Rectangle {
            id: bar

            required property int index
            // Right half runs top to bottom, the left half mirrors it back, like the dashboard's ring.
            readonly property int slot: index < root.count / 2 ? index : root.count - 1 - index
            readonly property real level: Cava.levels[Math.round(slot * (Cava.bars - 1) / (root.count / 2 - 1))] ?? 0

            x: root.width / 2 - width / 2
            y: root.height / 2 - root.art / 2 - Theme.bar.mediaGap - height
            width: Theme.spacing.hair
            height: Theme.spacing.hair + bar.level * Theme.bar.mediaReach
            radius: width / 2
            color: Theme.accentText
            opacity: Cava.running ? 1 : 0

            transform: Rotation {
                origin.x: bar.width / 2
                origin.y: bar.height + Theme.bar.mediaGap + root.art / 2
                angle: bar.index * 360 / root.count
            }

            Behavior on opacity {
                FastFade {}
            }
        }
    }

    ClippingRectangle {
        anchors.centerIn: parent
        implicitWidth: root.art
        implicitHeight: root.art
        radius: width / 2
        color: Theme.bgAlt

        MaterialIcon {
            anchors.centerIn: parent
            text: "music_note"
            color: Theme.fg
            size: Theme.icon.small
        }
    }

    Tip {
        anchorItem: root
        text: root.player ? (root.player.trackArtist ? root.player.trackArtist + " · " : "") + root.player.trackTitle : ""
        wanted: hover.hovered && !tap.pressed
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: root.player?.togglePlaying()
    }
}
