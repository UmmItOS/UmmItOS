import QtQuick
import QtQuick.Effects
import ".."

// Circle and haze are one shader pass; the line is only scaled.
Item {
    id: root

    property real dark: 0
    // Empty on the lock, which leaves a plain veil.
    property string picture: ""

    // Half the diagonal: a circle this wide reaches the corners.
    readonly property real reach: Math.hypot(width, height) / 2

    // From fully closed to its soft edge past the corners.
    function radius(progress: real): real {
        return -Theme.wakeSoft + progress * (reach + Theme.wakeSoft);
    }

    visible: dark > 0

    // The haze: the picture blurred, taken in by the shader, which dims it.
    Item {
        id: blurred

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
            blurMax: Theme.wakeBlur
            blur: 1
        }
    }

    ShaderEffectSource {
        id: hazeShot

        anchors.fill: parent
        sourceItem: blurred
        hideSource: true
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent

        property var source: hazeShot
        property size size: Qt.size(width, height)
        property real reveal: root.radius(Wake.open)
        property real soft: Theme.wakeSoft
        property real haze: Wake.haze
        property real dim: Theme.wakeDim
        property real hasPicture: before.status === Image.Ready ? 1 : 0

        fragmentShader: "curtain.frag.qsb"
    }

    // Blurred once at full width, then only scaled.
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
        visible: Wake.draw > 0 && Wake.open < 0.5
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
        opacity: 1 - Wake.open * 2
    }

    // …and a tighter core, so it reads as light, not haze.
    Glow {
        blurMax: Theme.spacing.large
        blur: 0.6
        opacity: (1 - Wake.open * 2) * 0.8
    }
}
