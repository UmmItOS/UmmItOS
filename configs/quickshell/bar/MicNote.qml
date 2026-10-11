pragma ComponentBehavior: Bound

import QtQuick
import ".."

// What the microphone sensor last reported (plugged in, pulled out), beside its disc; fades when stale.
Text {
    id: root

    textFormat: Text.PlainText
    text: MicCava.note
    color: MicCava.noteKind === "gone" || MicCava.noteKind === "muted" ? Theme.urgent : Theme.good
    elide: Text.ElideMiddle
    font.family: Theme.font
    font.pixelSize: Theme.fontSize.smaller
    opacity: MicCava.noting ? 1 : 0
    visible: opacity > 0
    width: Math.min(implicitWidth, Theme.bar.fileWatch)
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: root.opacity
    }

    Behavior on opacity {
        FastFade {}
    }

    Behavior on color {
        FastColor {}
    }
}
