pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import ".."

Item {
    id: root

    readonly property int art: Theme.bar.mediaArt
    readonly property int count: Theme.bar.mediaBars * 2

    property bool counted: false

    function sync(): void {
        if (root.visible === root.counted)
            return;
        root.counted = root.visible;
        MicCava.viewers += root.counted ? 1 : -1;
    }

    onVisibleChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: {
        if (root.counted)
            MicCava.viewers -= 1;
    }

    implicitWidth: art + (Theme.bar.mediaGap + Theme.bar.mediaReach) * 2
    implicitHeight: implicitWidth
    scale: tap.pressed ? Theme.pressScale : 1

    Accessible.role: Accessible.Button
    Accessible.name: I18n.t(MicCava.muted ? "Microphone muted" : "Microphone")

    Behavior on scale {
        PressAnim {}
    }

    Repeater {
        model: root.count

        Rectangle {
            id: bar

            required property int index
            // Right half runs top to bottom, the left half mirrors it back, like the music disc.
            readonly property int slot: index < root.count / 2 ? index : root.count - 1 - index
            readonly property real level: MicCava.levels[Math.round(slot * (MicCava.bars - 1) / (root.count / 2 - 1))] ?? 0

            x: root.width / 2 - width / 2
            y: root.height / 2 - root.art / 2 - Theme.bar.mediaGap - height
            width: Theme.spacing.hair
            height: Theme.spacing.hair + bar.level * Theme.bar.mediaReach
            radius: width / 2
            color: Theme.accentText
            opacity: MicCava.running ? 1 : 0

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
            text: MicCava.muted ? "mic_off" : "mic"
            color: MicCava.muted ? Theme.urgent : MicCava.inUse ? Theme.fg : Theme.dim
            size: Theme.icon.small

            Behavior on color {
                FastColor {}
            }
        }
    }

    Tip {
        anchorItem: root
        text: MicCava.muted ? I18n.t("Microphone muted") : MicCava.inUse ? I18n.t("Microphone in use") : I18n.t("Microphone")
        wanted: hover.hovered && !tap.pressed
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: MicCava.toggleMute()
    }
}
