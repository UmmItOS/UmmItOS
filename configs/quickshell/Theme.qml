pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property color bg: Qt.rgba(20 / 255, 20 / 255, 35 / 255, 0.72)
    readonly property color bgAlt: Qt.rgba(30 / 255, 25 / 255, 45 / 255, 0.82)
    // One step brighter than bgAlt, for a tray sitting on top of a panel.
    readonly property color bgTray: Qt.rgba(44 / 255, 37 / 255, 62 / 255, 0.78)
    // Saved from the bar's picker; accentText/accent2 derive from it.
    readonly property color defaultAccent: "#5003c0"
    property string savedAccent: ""
    readonly property color accent: /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(savedAccent) ? savedAccent : defaultAccent
    readonly property color accentText: Qt.hsla(Math.max(0, accent.hslHue), Math.min(accent.hslSaturation, 0.86), 0.72, 1)
    readonly property color accent2: Qt.hsla(Math.max(0, accent.hslHue), accent.hslSaturation, 0.82, 1)

    function setAccent(c: color): void {
        savedAccent = c.toString();
        accentFile.setText(savedAccent);
    }

    FileView {
        id: accentFile
        path: Quickshell.statePath("accent.txt")
        printErrors: false
        blockWrites: false
        onLoaded: root.savedAccent = text().trim()
    }
    // Ink over a panel on Hyprland's blur; lower shows more of it.
    readonly property real panelTint: 0.45
    // A card on a blurred panel: a faint sheen, not a fill.
    readonly property color glass: Qt.rgba(1, 1, 1, 0.04)
    readonly property color fg: "#e8e8f0"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.45)
    readonly property color urgent: "#ff6b6b"
    readonly property color warn: "#ffc46b"
    readonly property color good: "#6bdf9a"
    // The window border's hues, darkened, for the cheat sheet ring.
    readonly property list<color> ring: ["#4a3d94", "#5a4f8c", "#12131b", "#2f4a7d"]

    // Ink, not black: black reads as a hole and kills the blur behind.
    function scrim(alpha: real): color {
        return Qt.rgba(bg.r, bg.g, bg.b, alpha);
    }

    readonly property string font: "SF Pro Text"
    readonly property string fontDisplay: "SF Pro Display"

    // Material 3 scales, from caelestia-dots/shell tokens.hpp.
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
        // Optical nudge for text flush against a rounded edge.
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
        // The launcher's query line, which is the whole of its chrome.
        readonly property int query: 54
        // The dashboard clock.
        readonly property int hero: 78
        // The OSD's number, which is the only thing on screen when it appears.
        readonly property int huge: 46
    }

    // Small labels want wider tracking and more weight.
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

    readonly property int barHeight: 44
    // Hyprland gaps_out (20) + border_size (3).
    readonly property int windowInset: 23
    // How far the waking line's soft light spills.
    readonly property int wakeGlow: 90
    // How wide the soft edge of the waking circle is.
    readonly property int wakeSoft: 320
    // The wake's haze: the screen before sleep, heavily blurred.
    readonly property int wakeBlur: 64
    // How dark the waking picture starts, before it brightens to the screen.
    readonly property real wakeDim: 0.3

    // How far a pressed control sinks under the finger.
    readonly property real pressScale: 0.92
    // Where an opening surface grows from, as a fraction of its full size.
    readonly property real popScale: 0.94
    // A countdown number lands from this size.
    readonly property real landScale: 1.6

    readonly property QtObject icon: QtObject {
        // An app's own icon beside its notification, at caption size.
        readonly property int tiny: 16
        readonly property int small: 20
        // Tray icons: the size SNI items are drawn for.
        readonly property int tray: 22
        readonly property int normal: 24
        readonly property int large: 30
        readonly property int extraLarge: 46
        readonly property int huge: 52
        // Launcher tiles, where the icon is the content.
        readonly property int app: 60
    }

    // A wallpaper card's glow in its own colours; a dark shadow vanished on the dark wash.
    readonly property QtObject cardGlow: QtObject {
        readonly property int blur: 64
        // Decoded this small: it is blurred to mush anyway.
        readonly property int sourceWidth: 96
        readonly property real alpha: 0.45
        readonly property real alphaFocused: 0.9
        // How far past the card the glow starts, before the blur spreads it further.
        readonly property int spread: 24
    }
    // The lecture pen (draw/).
    readonly property QtObject draw: QtObject {
        readonly property var widths: [3, 6, 12]
        // A highlighter is this much wider than the pen, and see-through.
        readonly property real highlightWidth: 4
        readonly property real highlightAlpha: 0.35
        readonly property real zoomMax: 6
        readonly property real zoomStep: 1.15
        // Touchpad scroll arrives in pixels; this many make one zoom step.
        readonly property real scrollPixels: 40
    }
    readonly property QtObject control: QtObject {
        // A list row in a flyout or the clipboard.
        readonly property int row: 46
        // A text field or an action chip.
        readonly property int field: 34
        // A round icon button.
        readonly property int button: 40
        // A tray app's right-click menu.
        readonly property int menu: 300
        // A small centred dialog (the recording one).
        readonly property int dialog: 420
        // A pill-shaped button or search field.
        readonly property int pill: 44
        // Room for a live number ("12.4 M", "100 %") so it does not jitter.
        readonly property int readout: 46
        // A notification's preview image.
        readonly property int thumbWidth: 120
        readonly property int thumbHeight: 68
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
        // One turn of a spinner.
        readonly property int spin: 900
        // The screen coming up out of black on wake.
        readonly property int wake: 2400
        // How long a wake hold() may stay black without a play().
        readonly property int wakeSafety: 6000
        // Gap between siblings entering one after another.
        readonly property int stagger: 40
    }

    // The lock screen's sizes, kept from hyprlock so the switch looks the same.
    readonly property QtObject lock: QtObject {
        readonly property int clock: 180
        readonly property int date: 32
        readonly property int user: 24
        readonly property int hint: 16
        readonly property int battery: 14
        readonly property int avatar: 100
        readonly property int ring: 3
        readonly property int field: 60
    }

    // Lower damping overshoots more.
    readonly property QtObject spring: QtObject {
        readonly property real stiffness: 12
        readonly property real damping: 0.55
    }

    // Bezier control points for Easing.BezierSpline.
    readonly property QtObject curve: QtObject {
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
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
