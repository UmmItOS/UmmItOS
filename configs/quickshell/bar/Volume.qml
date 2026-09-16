import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null

    // Without a tracker the node's audio properties stay unbound and read empty.
    PwObjectTracker {
        objects: [root.sink]
    }

    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: !root.audio ? "" : root.audio.muted ? "volume_off" : root.audio.volume > 0.5 ? "volume_up" : "volume_down"
        color: root.audio && root.audio.muted ? Theme.dim : Theme.fg
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        visible: root.audio
        text: !root.audio ? "" : root.audio.muted ? "muted" : Math.round(root.audio.volume * 100) + " %"
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
    }

    // Handlers rather than a MouseArea: a MouseArea is an Item and anchoring
    // one inside a Layout is undefined behavior.
    TapHandler {
        onTapped: {
            if (root.audio)
                root.audio.muted = !root.audio.muted;
        }
    }

    WheelHandler {
        onWheel: event => {
            if (!root.audio)
                return;
            const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
            root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + step));
        }
    }
}
