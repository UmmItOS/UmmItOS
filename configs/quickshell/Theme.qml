pragma Singleton

import Quickshell
import QtQuick

Singleton {
    // Palette taken from configs/waybar/style.css so both bars look the same
    // while they run side by side.
    readonly property color bg: Qt.rgba(20 / 255, 20 / 255, 35 / 255, 0.72)
    readonly property color bgAlt: Qt.rgba(30 / 255, 25 / 255, 45 / 255, 0.82)
    // One step brighter than bgAlt, for a tray sitting on top of a panel.
    readonly property color bgTray: Qt.rgba(44 / 255, 37 / 255, 62 / 255, 0.78)
    // Brand purple. It is dark (L 38%), so it is used for fills, borders and
    // solid shapes; `accentText` is the same hue lifted to stay readable as
    // text on the dark background.
    readonly property color accent: "#5003c0"
    readonly property color accentText: "#a97bf5"
    readonly property color accent2: "#c9a3ff"
    readonly property color fg: "#e8e8f0"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.45)
    readonly property color urgent: "#ff6b6b"
    readonly property color warn: "#ffc46b"
    readonly property color good: "#6bdf9a"

    // Proportional for prose, monospace for anything that should not jitter as
    // it updates (clock, percentages, counters). SF Pro ships with apple-fonts,
    // already in install/packages_main.
    // Overlay backdrops take the ink colour, never pure black: black reads as
    // a hole punched in the desktop rather than the shell dimming it, and it
    // kills the compositor blur behind the surface.
    function scrim(alpha: real): color {
        return Qt.rgba(bg.r, bg.g, bg.b, alpha);
    }

    readonly property string font: "SF Pro Text"
    readonly property string fontDisplay: "SF Pro Display"

    // Material 3 scales, values from caelestia-dots/shell
    // (plugin/src/Caelestia/Config/tokens.hpp).
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 32
        readonly property int extraLargeIncreased: 32
        readonly property int extraExtraLarge: 48
        readonly property int full: 1000
    }

    readonly property QtObject spacing: QtObject {
        // Optical, not structural: a nudge for text that sits flush against a
        // rounded edge and reads tighter than it measures.
        readonly property int hair: 2
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 32
        readonly property int extraLargeIncreased: 32
    }

    readonly property QtObject padding: QtObject {
        readonly property int extraSmall: 4
        readonly property int small: 8
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 32
    }

    readonly property QtObject fontSize: QtObject {
        readonly property int small: 12
        readonly property int smaller: 13
        readonly property int normal: 15
        readonly property int larger: 17
        readonly property int large: 21
        readonly property int extraLarge: 32
    }

    // Icons do not follow the text scale: a glyph needs more room than a
    // letter at the same nominal size.
    // Type is set, not just sized: small labels want air between letters and a
    // little more weight, or they read as shrunken body copy.
    readonly property QtObject tracking: QtObject {
        readonly property real normal: 0
        readonly property real wide: 0.4
        readonly property real wider: 0.8
    }

    readonly property QtObject weight: QtObject {
        readonly property int regular: 400
        readonly property int medium: 500
        readonly property int bold: 700
    }

    // Anything that positions itself under the bar reads this rather than
    // repeating the number.
    readonly property int barHeight: 44

    readonly property QtObject icon: QtObject {
        readonly property int small: 20
        readonly property int normal: 24
        readonly property int large: 30
        readonly property int extraLarge: 46
    }

    readonly property QtObject duration: QtObject {
        readonly property int small: 200
        readonly property int normal: 400
        readonly property int large: 600
        readonly property int extraLarge: 1000
        readonly property int expressiveFastSpatial: 350
        readonly property int expressiveDefaultSpatial: 500
        readonly property int expressiveFastEffects: 150
        readonly property int expressiveDefaultEffects: 200
        readonly property int expressiveSlowEffects: 300
        // One turn of a spinner, and how long a flyout waits before closing
        // itself once the pointer has left.
        readonly property int spin: 900
        readonly property int linger: 2500
    }

    // Bezier control points for Easing.BezierSpline.
    readonly property QtObject curve: QtObject {
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property list<real> expressiveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
        readonly property list<real> expressiveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]
    }
}
