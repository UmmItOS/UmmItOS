import QtQuick
import QtQuick.Effects

// A layer.effect: out of focus at settled 0, sharp at 1. Enable the layer only while settled < 1.
MultiEffect {
    required property real settled

    blurEnabled: true
    blurMax: Theme.motionBlur
    blur: 1 - Math.max(0, Math.min(1, settled))
}
