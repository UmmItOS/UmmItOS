import QtQuick
import QtQuick.Effects
import ".."

// The wake, drawn in three beats timed by Wake. A soft line of light draws
// out from the centre of the black; the black opens from it in a soft
// circle onto a dim, blurred screen; then a second circle, behind the
// first, clears that haze to the sharp screen. Both circles are one shader
// pass (wake.frag), and the line is blurred once and only scaled, so
// nothing is re-drawn or resized per frame.
Item {
    id: root

    property real dark: 0
    // The screen as it was before going black, shown blurred as the haze;
    // empty where there is none (the lock), which leaves the haze plain dim.
    property string picture: ""

    // Half the diagonal: a circle this wide reaches the corners.
    readonly property real reach: Math.hypot(width, height) / 2

    // A circle's radius for a beat's progress, starting fully closed
    // (its soft edge ending at the centre) and ending with that edge past
    // the corners.
    function radius(progress: real): real {
        return -Theme.wakeSoft + progress * (reach + Theme.wakeSoft);
    }

    visible: dark > 0

    // The haze: the picture blurred, taken in by the shader, which dims it.
    Item {
        id: haze

        anchors.fill: parent

        Image {
            id: before

            anchors.fill: parent
            source: root.picture
            asynchronous: true
            cache: false
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: before
            visible: before.status === Image.Ready
            blurEnabled: true
            blurMax: Theme.blur.max
            blur: 1
        }
    }

    ShaderEffectSource {
        id: hazeShot

        anchors.fill: parent
        sourceItem: haze
        hideSource: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        property var source: hazeShot
        property size size: Qt.size(width, height)
        property real rOpen: root.radius(Wake.lids)
        property real rClear: root.radius(Wake.circle)
        property real soft: Theme.wakeSoft
        property real dim: Theme.wakeDim
        property real hasPicture: before.status === Image.Ready ? 1 : 0

        fragmentShader: "wake.frag.qsb"
    }

    // The line: a pill of light blurred once at full width and grown by
    // stretching it from the centre. It fades as the black opens.
    Rectangle {
        id: pill

        anchors.centerIn: parent
        width: parent.width
        height: Theme.spacing.small
        radius: height / 2
        color: Theme.accent2
        visible: false
        layer.enabled: true
    }

    component Glow: MultiEffect {
        anchors.fill: pill
        source: pill
        autoPaddingEnabled: true
        blurEnabled: true
        visible: Wake.draw > 0 && Wake.lids < 0.5
        transform: Scale {
            origin.x: root.width / 2
            xScale: Wake.draw
        }
    }

    // A wide soft halo…
    Glow {
        blurMax: Theme.wakeGlow
        blur: 1
        brightness: 0.2
        opacity: 1 - Wake.lids * 2
    }

    // …and a tighter core, so it reads as light, not haze.
    Glow {
        blurMax: Theme.spacing.large
        blur: 0.6
        opacity: (1 - Wake.lids * 2) * 0.8
    }
}
