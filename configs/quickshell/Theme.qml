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
    // The accent is chosen in the bar and saved; brand purple until then. It
    // is a fill colour. `accentText` and `accent2` are the same hue lifted so
    // they stay readable as text on the dark ground, derived rather than
    // stored, so any accent brings its own.
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
    readonly property color fg: "#e8e8f0"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.45)
    readonly property color urgent: "#ff6b6b"
    readonly property color warn: "#ffc46b"
    readonly property color good: "#6bdf9a"
    // Hyprland's active border (windows.conf col.active_border), same hues
    // and order, darkened: the cheat sheet wears it as a turning ring.
    readonly property list<color> ring: ["#4a3d94", "#5a4f8c", "#12131b", "#2f4a7d"]

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
        // The launcher's query line, which is the whole of its chrome.
        readonly property int query: 54
        // The dashboard clock.
        readonly property int hero: 78
        // The OSD's number, which is the only thing on screen when it appears.
        readonly property int huge: 46
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
    // Where tiled windows' borders sit, in from the screen edge: Hyprland's
    // gaps_out (20) plus border_size (3). Things meant to sit inside that
    // frame, not over it, keep at least this far in.
    readonly property int windowInset: 23

    // How far a pressed control sinks under the finger.
    readonly property real pressScale: 0.92
    // Where an opening surface grows from, as a fraction of its full size.
    readonly property real popScale: 0.94

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

    // Controls that recur across surfaces, so a row in the Wi-Fi list and one
    // in the Bluetooth list stay the same height.
    readonly property QtObject control: QtObject {
        // A list row in a flyout or the clipboard.
        readonly property int row: 46
        // A text field or an action chip.
        readonly property int field: 34
        // A round icon button.
        readonly property int button: 40
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

    // Springs for things that should trail the pointer and settle, not just
    // follow it: lower damping overshoots more.
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
