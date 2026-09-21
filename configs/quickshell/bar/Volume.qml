pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real level: audio ? audio.volume : 0

    property bool popupOpen: false

    // Without a tracker the node's audio properties stay unbound and read empty.
    PwObjectTracker {
        objects: [root.sink]
    }

    function setVolume(value: real): void {
        if (root.audio)
            root.audio.volume = Math.max(0, Math.min(1, value));
    }

    function glyphFor(level: real, muted: bool): string {
        if (muted)
            return "volume_off";
        if (level < 0.01)
            return "volume_mute";
        return level > 0.5 ? "volume_up" : "volume_down";
    }

    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: root.glyphFor(root.level, root.audio?.muted ?? false)
        color: root.audio && root.audio.muted ? Theme.dim : Theme.fg
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: !root.audio ? "" : root.audio.muted ? "muted" : Math.round(root.level * 100) + " %"
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
        font.features: ({
                tnum: 1
            })
    }

    // Click opens the slider; the wheel still works without opening anything.
    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    WheelHandler {
        onWheel: event => root.setVolume(root.level + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    PopupWindow {
        id: popup

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: Theme.spacing.small

        visible: root.popupOpen
        implicitWidth: 300
        implicitHeight: 84
        color: "transparent"

        HoverHandler {
            id: popupHover
        }

        // Leaving the popup closes it: a volume flyout should not need dismissing.
        Timer {
            running: root.popupOpen && !popupHover.hovered && !barHover.hovered
            interval: 900
            onTriggered: root.popupOpen = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.extraLarge
            color: Theme.bg

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.padding.large
                    rightMargin: Theme.padding.large
                }
                spacing: Theme.spacing.large

                // Mute lives here now that the bar click opens the slider.
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: width / 2
                    color: (root.audio?.muted ?? false) ? Theme.accent : Theme.bgTray

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: root.glyphFor(root.level, root.audio?.muted ?? false)
                        color: Theme.fg
                        fill: (root.audio?.muted ?? false) ? 1 : 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (root.audio)
                                root.audio.muted = !root.audio.muted;
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: 28

                    Rectangle {
                        id: track
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        implicitHeight: 8
                        radius: height / 2
                        color: Theme.bgTray

                        Rectangle {
                            width: track.width * root.level
                            height: parent.height
                            radius: height / 2
                            color: (root.audio?.muted ?? false) ? Theme.dim : Theme.accentText
                        }
                    }

                    Rectangle {
                        id: knob
                        x: track.width * root.level - width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: drag.pressed ? 20 : 16
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: Theme.fg

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }
                    }

                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        anchors.margins: -6

                        function apply(x: real): void {
                            root.setVolume(x / track.width);
                        }

                        onPressed: event => apply(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                apply(event.x);
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 46
                    text: Math.round(root.level * 100) + "%"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.features: ({
                            tnum: 1
                        })
                }
            }
        }
    }

    HoverHandler {
        id: barHover
    }
}
