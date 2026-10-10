pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // The desktop's "animations" switch (GNOME's key, which GTK apps follow too); false means reduce motion.
    property bool reduceMotion: false

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
    // Text and icons drawn on an accent fill: ink on a light accent, fg on a dark one (WCAG luminance, 0.17 is where both contrast equally).
    readonly property color accentOn: luminance(accent) > 0.17 ? Qt.rgba(bg.r, bg.g, bg.b, 1) : fg
    // Ink over a panel on Hyprland's blur; lower shows more of it.
    readonly property real panelTint: 0.45
    // A card on a blurred panel: a faint sheen, not a fill.
    readonly property color glass: Qt.rgba(1, 1, 1, 0.04)
    readonly property color fg: "#e8e8f0"
    // About 7:1 over the panel; 0.45 sat on the 4.5:1 line and fell below it over a bright wallpaper.
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)
    readonly property color urgent: "#ff6b6b"
    readonly property color warn: "#ffc46b"
    readonly property color good: "#6bdf9a"
    // The window border's hues, darkened, for the cheat sheet ring.
    readonly property list<color> ring: ["#4a3d94", "#5a4f8c", "#12131b", "#2f4a7d"]

    readonly property string font: "SF Pro Text"
    readonly property string fontDisplay: "SF Pro Display"
    // Raw content and hex dumps, where columns must line up.
    readonly property string fontMono: "JetBrains Mono"
    // A lone Chinese glyph drawn large, in Hong Kong forms rather than whatever fallback Qt finds.
    readonly property string fontCjk: "Noto Sans CJK HK"

    // Material 3 scales, from caelestia-dots/shell tokens.hpp.
    readonly property QtObject rounding: QtObject {
        readonly property int extraSmall: 4
        readonly property int medium: 12
        readonly property int large: 16
        readonly property int largeIncreased: 20
        readonly property int extraLarge: 32
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
    // A control that cannot be used right now.
    readonly property real disabledOpacity: 0.4
    // A countdown number lands from this size.
    readonly property real landScale: 1.6
    // How out of focus a surface is when it starts to arrive (MotionBlur).
    // None when the system asks for less motion: things fade in sharp.
    readonly property int motionBlur: reduceMotion ? 0 : 40
    // Pointer travel under this is jitter, not a move.
    readonly property int pointerSlop: 2
    // How far a small target's click area reaches past what it draws.
    readonly property int hitSlop: 4
    // A divider's thickness.
    readonly property int hairline: 1
    // A window's size before it knows its screen.
    readonly property size fallbackScreen: Qt.size(1920, 1080)

    // Qt.lighter() on a Surface's top edge; larger surfaces take less, or it shows as a band.
    readonly property QtObject lift: QtObject {
        readonly property real card: 1.22
        readonly property real panel: 1.12
        readonly property real sheet: 1.1
        readonly property real osd: 1.3
        // Where the lift has faded into the tone.
        readonly property real reach: 0.6
    }

    // Scrim alphas behind full-screen surfaces.
    readonly property QtObject shade: QtObject {
        readonly property real light: 0.45
        readonly property real normal: 0.5
        readonly property real heavy: 0.78
        // A card inside a glass panel.
        readonly property real card: 0.35
        // Outside a screenshot selection.
        readonly property real outside: 0.6
    }

    // A live indicator's breath.
    readonly property QtObject pulse: QtObject {
        // How far a blinking icon dims.
        readonly property real charging: 0.35
        readonly property real recording: 0.3
        readonly property real haloScale: 1.8
        readonly property real haloOpacity: 0.35
    }

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
        readonly property int app: 112
        // Material Symbols GRAD: a lighter stroke, which reads right on a dark ground.
        readonly property int grade: -25
    }

    // How far in from a wallpaper card's edge its picture fades out, so no edge shows.
    readonly property int cardFeather: 56
    // A desktop widget's width (a medium macOS widget).
    readonly property int widgetWidth: 340

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
        // Zoom steps per keypress.
        readonly property int keySteps: 3
        // The toolbar steps back while a stroke is drawn.
        readonly property real toolbarDrawing: 0.2
    }

    // The QR scanner (scan/).
    readonly property QtObject scan: QtObject {
        // How far the highlight reaches past a code's edge.
        readonly property int reach: 12
        // A code's label, at most.
        readonly property int card: 340
        // The detail panel beside the codes.
        readonly property int panel: 500
        // The code's own picture in the panel: at least this tall, else this share of the panel's height.
        readonly property int picture: 168
        readonly property real pictureShare: 0.2
        // Past this many bytes the hex dump stops and says how many are left.
        readonly property int hexBytes: 512
        readonly property int hexColumns: 8
        // The accent wash over a code, at rest and when picked.
        readonly property real tint: 0.14
        readonly property real tintPeak: 0.3
    }

    // The settings panel (settings/).
    readonly property QtObject settings: QtObject {
        readonly property int width: 880
        readonly property int height: 600
        readonly property int sidebar: 200
        // A setting's control column, so every chooser lines up.
        readonly property int choice: 320
        // How far a page travels as it leaves and the next one arrives.
        readonly property int pageShift: 24
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
        readonly property int toggleKnob: 20
        readonly property int toggleInset: 3
        readonly property int slider: 28
        readonly property int sliderTrack: 8
        readonly property int sliderKnob: 16
        // A bar dropdown; the height is for one that does not hug its content.
        readonly property int flyout: 380
        readonly property int flyoutHeight: 420
    }

    readonly property QtObject bar: QtObject {
        // The little cover with audio bars beside the clock: the cover, the gap to the bars, how far they reach, and how many per half.
        readonly property int mediaArt: 24
        readonly property int mediaGap: 2
        readonly property int mediaReach: 6
        readonly property int mediaBars: 8
        // The latest-file-change label, before it elides.
        readonly property int fileWatch: 220
        // The pill round a group of bar items.
        readonly property int cluster: 32
        readonly property int accentColumns: 4
        // Your own colours shown at most, one row.
        readonly property int accentYours: 4
        // How much a swatch lightens under the pointer.
        readonly property real swatchHover: 1.15
        // Bytes per second; below it the bandwidth arrows stay idle.
        readonly property int busyAt: 2048
        readonly property int workspace: 24
        readonly property int workspaceMin: 30
        readonly property int workspaceDot: 10
        // Marks a bar button whose action is narrowed, like shuffle limited to one folder.
        readonly property int badge: 6
        readonly property real workspaceIdle: 0.28
        readonly property real workspaceGlowBlur: 0.9
        readonly property real workspaceGlow: 0.55
    }

    readonly property QtObject battery: QtObject {
        // Percent; drivers report "fully charged" briefly on plug-in.
        readonly property int full: 99
        readonly property real low: 0.2
        readonly property real critical: 0.15
    }

    readonly property QtObject volume: QtObject {
        // Per wheel notch; touchpads send fractions of one.
        readonly property real wheelStep: 0.05
        // Below this reads as silent.
        readonly property real silent: 0.01
        // Above this the icon shows full waves.
        readonly property real high: 0.5
    }

    readonly property QtObject osd: QtObject {
        readonly property int size: 208
        readonly property int segments: 16
        readonly property int segmentWidth: 6
        readonly property int segmentHeight: 14
        // The input method dots, and the pill marking the one in use.
        readonly property int dot: 8
        readonly property int dotPill: 22
        readonly property real mutedIcon: 0.4
        readonly property real brightnessHigh: 0.6
        readonly property real brightnessMedium: 0.25
    }

    readonly property QtObject notification: QtObject {
        // Toasts and the panel alike.
        readonly property int width: 420
        // How far a toast slides in from.
        readonly property int slide: 60
        readonly property int lines: 6
        readonly property int collapsedLines: 4
        // Toasts on screen at once; a flood that never expires still leaves the screen usable (older ones stay in history).
        readonly property int max: 6
        // A body is cut here before parsing: megabytes of markup would stall the shell for seconds.
        readonly property int bodyChars: 4000
    }

    // The copy notices (toast/).
    readonly property QtObject toast: QtObject {
        readonly property int width: 620
        // A burst of copies should not climb up the whole screen.
        readonly property int max: 5
        // A leaving pill slides this share of the column.
        readonly property real exit: 1 / 3
    }

    readonly property QtObject launcher: QtObject {
        readonly property int cellMin: 220
        // The icon plus two lines of name.
        readonly property int cellHeight: 224
        readonly property int minColumns: 4
        readonly property int nameLines: 2
        readonly property real glow: 0.5
        readonly property real activeScale: 1.04
    }

    readonly property QtObject gallery: QtObject {
        // A thumbnail's width at least; the grid widens them to fill the row.
        readonly property int cellMin: 340
        readonly property int minColumns: 3
        // Height over width of a thumbnail.
        readonly property real ratio: 0.5625
        // The name and time under it.
        readonly property int label: 52
        // The cards fly in from scattered spots: a pause per card, how far they start (a share of the grid), the most they tilt, and how long a card created after opening still joins in.
        readonly property int stagger: 22
        readonly property real scatter: 0.9
        readonly property int tilt: 40
        readonly property int arrival: 1600
        readonly property real glow: 0.5
        readonly property real activeScale: 1.03
        // How big the grid grows while it leaves for the folder you opened.
        readonly property real enterScale: 1.12
    }

    readonly property QtObject clipboard: QtObject {
        readonly property int width: 980
        readonly property int height: 600
        // The index; narrow on purpose, it is for scanning.
        readonly property int index: 360
        readonly property int decode: 1100
        readonly property real lineHeight: 1.35
    }

    readonly property QtObject session: QtObject {
        readonly property int tile: 156
        readonly property real activeScale: 1.06
        readonly property real glow: 0.6
    }

    readonly property QtObject cheatsheet: QtObject {
        readonly property int width: 1400
        readonly property int ring: 3
        // Padding round the ring's capture, or its blur stops at the edge.
        readonly property int glowPad: 48
        readonly property real glowBrightness: 0.45
        readonly property real glowSaturation: 0.4
        readonly property real ringOpacity: 0.5
        // The light that follows the pointer.
        readonly property int spot: 360
        readonly property real spotCore: 0.28
        readonly property real spotEdge: 0.1
        readonly property real spotEdgeAt: 0.45
        readonly property int column: 440
        readonly property int keys: 180
    }

    readonly property QtObject dashboard: QtObject {
        readonly property int width: 1100
        readonly property int height: 520
        readonly property int clock: 210
        readonly property int gauge: 170
        readonly property int gaugeRing: 10
        readonly property int gaugeStart: 130
        readonly property int gaugeSweep: 280
        // System facts: a value may take this share of the row.
        readonly property int factShare: 4
        readonly property int systemCard: 92
        readonly property int workspaceColumns: 4
        readonly property int workspaceCell: 120
        readonly property int workspaceLines: 3
        readonly property real otherMonth: 0.5
        readonly property int art: 170
        // How far the audio bars reach out from the art.
        readonly property int artReach: 34
        readonly property int artDecode: 380
        readonly property int play: 52
        readonly property int progress: 6
        readonly property int chip: 28
    }

    readonly property QtObject switcher: QtObject {
        // The hot corner's size.
        readonly property int corner: 3
        readonly property int columns: 3
        // A fourth column past this many costs less than a fourth row.
        readonly property int wideAfter: 8
        readonly property int maxColumns: 4
        readonly property int cellMax: 620
        readonly property real aspect: 0.62
        // Windows previewed per card.
        readonly property int previews: 4
        readonly property real dim: 0.5
        readonly property real dimOverview: 0.35
        readonly property real glow: 0.75
        readonly property real captionWidth: 0.7
        // The sharp picture fades in faster than the zoom.
        readonly property real shotFade: 1.6
        readonly property int rings: 3
        readonly property int ringReach: 384
        readonly property real ringSpeed: 1.4
        readonly property real ringStagger: 0.2
        readonly property real ringOpacity: 0.9
    }

    readonly property QtObject screenshot: QtObject {
        readonly property real zoomMax: 4
        readonly property real zoomStep: 1.15
        // Smaller than this is a click, which takes the whole screen.
        readonly property int minSelection: 4
        // Smaller windows are popups and tooltips, not pickable.
        readonly property int minWindow: 40
        readonly property int blurMax: 64
        readonly property real blur: 0.45
        readonly property real blurWindow: 0.25
        readonly property real hint: 0.75
        readonly property int tendrilTip: 4
        readonly property int tendrilSegments: 40
        // Bezier control points as shares of the run.
        readonly property real bendX: 0.7
        readonly property real bendY: 0.4
        readonly property int swayMax: 18
        readonly property real sway: 0.04
        readonly property real waves: 1.6
        // Where in the sprout the corner dots arrive.
        readonly property real cornersAt: 0.6
        readonly property real cornerPulse: 0.2
    }

    readonly property QtObject wallpaper: QtObject {
        // A full-size 4K decode costs frames; 1.25x leaves room for the crop.
        readonly property real decodeScale: 1.25
        // awww's corner origin; it measures y from the bottom, so 0.969 is near the top.
        readonly property real originX: 0.977
        readonly property real originY: 0.969
    }

    readonly property QtObject picker: QtObject {
        readonly property int cardWidth: 420
        readonly property int cardHeight: 236
        readonly property real shrink: 0.5
        readonly property int height: 460
        // Room above the focused card for its lift.
        readonly property int headroom: 40
        readonly property real fadeAt: 0.45
        readonly property real fadeAlpha: 0.72
        readonly property real floorAlpha: 0.94
        // The page turn's starting angle.
        readonly property int swing: 80
        // Cards on screen: the width over this share of a card.
        readonly property real cardSpan: 0.72
        readonly property int minCards: 3
        readonly property int focusLift: -18
        readonly property real unfocused: 0.62
        readonly property real folder: 0.45
        readonly property int dot: 8
    }

    readonly property QtObject charge: QtObject {
        readonly property int sparks: 700
        readonly property int steps: 90
        readonly property int line: 2
        // Past the farthest corner, so the ring leaves the screen.
        readonly property real reach: 1.05
        // The ring runs ahead so it leaves while the glitter settles.
        readonly property real lead: 1.25
        readonly property real band: 0.2
        readonly property real echo: 0.72
        readonly property real echoAlpha: 0.35
        readonly property real fadeFrom: 0.6
        readonly property real labelIn: 0.15
    }

    readonly property QtObject wake: QtObject {
        // Beats along the wake's progress.
        readonly property real drawEnd: 0.3
        readonly property real openStart: 0.22
        readonly property real hazeStart: 0.3
        readonly property real haloBrightness: 0.2
        readonly property real coreBlur: 0.6
        readonly property real coreOpacity: 0.8
    }

    readonly property QtObject record: QtObject {
        // Seconds counted down before recording starts.
        readonly property int countdown: 5
    }

    readonly property QtObject duration: QtObject {
        // How often the time on the current accent is counted and saved.
        readonly property int accentTick: 60000
        readonly property int small: 200
        readonly property int normal: 400
        readonly property int extraLarge: 1000
        // Slides, scales and zooms; instant when the system asks for less motion, so only fades remain.
        readonly property int expressiveFastSpatial: root.reduceMotion ? 0 : 350
        readonly property int expressiveDefaultSpatial: root.reduceMotion ? 0 : 500
        readonly property int expressiveFastEffects: 150
        readonly property int expressiveDefaultEffects: 200
        readonly property int expressiveSlowEffects: 300
        // One turn of a spinner.
        readonly property int spin: 900
        // One breath of a status dot's glow.
        readonly property int glow: 1800
        // The screen coming up out of black on wake.
        readonly property int wake: 2400
        // How long a wake hold() may stay black without a play().
        readonly property int wakeSafety: 6000
        // Gap between siblings entering one after another.
        readonly property int stagger: 40
        // How long the pointer rests on an icon-only control before its tip shows.
        readonly property int tipDelay: 600
        // How often the desktop weather is fetched again.
        readonly property int weatherRefresh: 1800000
        // How soon a fetch that failed for want of network is tried again.
        readonly property int weatherRetry: 60000
        // How long the recorder may take to report in before its dialog opens again.
        readonly property int recordStart: 8000
        // How long the panel's "Clear all?" waits for the second click.
        readonly property int confirmHold: 3000
        // A toast that set no timeout of its own.
        readonly property int toast: 6000
        // An image copied this soon after a screenshot is that screenshot, which has its shutter already.
        readonly property int shotCopy: 3000
        // The longest a colour pick may take before its copy is heard again.
        readonly property int pickMute: 60000
        // Hyprland sends a pair of urgent events about 10 ms apart for one request; clicks even 150 ms apart stay separate.
        readonly property int urgentRepeat: 150
        // An app that sent its own notification this recently gets no attention notice on top.
        readonly property int urgentQuiet: 5000
        readonly property int osdHide: 1400
        // Settle before arming the OSD, or a new sink flashes a volume nobody touched.
        readonly property int osdArm: 1200
        // A method change this soon after a focus change is that window's own, not a switch.
        readonly property int imeFocus: 400
        // A method switch is a glance, not a value to watch, so it leaves sooner than osdHide.
        readonly property int imeHide: 600
        // An input card leaves faster than a volume card: it was only a glance.
        readonly property int imeLeave: 250
        // Before listening for switches again after fcitx or the bus went away.
        readonly property int imeRetry: 5000
        // How long a Wi-Fi scan may run before the spinner gives up.
        readonly property int scanGrace: 12000
        // awww's --transition-duration 2.5.
        readonly property int wallpaperReveal: 2500
        readonly property int previewDebounce: 140
        readonly property int decodeDebounce: 120
        readonly property int ringTurn: 5000
        // One sway of the screenshot tendrils.
        readonly property int sway: 2600
        // Held this long, so brushing past the hot corner does not count.
        readonly property int hotCorner: 80
        // The most the switcher waits for its previews to warm up.
        readonly property int warmLimit: 150
        // The most the lock waits on a picture before releasing.
        readonly property int lockWait: 300
        readonly property int frame: 16
        // A wrong password's head shake, step by step.
        readonly property list<int> shake: [50, 90, 80, 60]
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
        // hyprlock's background: light blur, some contrast, brightness 0.8.
        readonly property int blurMax: 32
        readonly property real blur: 0.3
        readonly property real contrast: 0.08
        readonly property real veil: 0.2
        // hyprlock's per-element shadow: size, passes and how it spreads.
        readonly property int shadow: 3
        readonly property int shadowClock: 4
        readonly property int shadowText: 2
        readonly property int shadowPasses: 2
        readonly property int shadowBlurMax: 16
        readonly property real shadowOpacity: 0.85
        readonly property real shadowScale: 1.02
        // Positions as shares of the screen height, and widths of its width.
        readonly property real margin: 0.01
        readonly property real dateAt: 0.15
        readonly property real clockAt: 0.05
        readonly property real avatarAt: -0.15
        readonly property real userAt: -0.21
        readonly property real hintAt: -0.24
        readonly property real fieldAt: -0.29
        readonly property real fieldWidth: 0.15
        readonly property color dateInk: Qt.rgba(1, 1, 1, 0.8)
        readonly property color userInk: Qt.rgba(1, 1, 1, 0.9)
        readonly property color hintInk: Qt.rgba(1, 1, 1, 0.6)
        readonly property color placeholderInk: Qt.rgba(1, 1, 1, 0.5)
        readonly property color ringInk: Qt.rgba(1, 1, 1, 0.3)
        readonly property color glass: Qt.rgba(1, 1, 1, 0.1)
        readonly property color glassStrong: Qt.rgba(1, 1, 1, 0.2)
        readonly property color failed: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.7)
        // Frames to wait for the wallpaper (about lockWait) and after it is ready.
        readonly property int maxFrames: 18
        readonly property int settleFrames: 2
    }

    // The SAO menu (sao/): Sword Art Online's own palette and sizes, apart from the shell's look on purpose.
    readonly property QtObject sao: QtObject {
        readonly property color paper: "#cfd0c5"
        readonly property color paperDeep: "#bdbeb2"
        readonly property color ink: "#616256"
        // SAO's ink, darker: the anime's palette was made for large text on a TV, this one reads at desktop sizes.
        readonly property color inkDeep: "#4a4b41"
        readonly property color orange: "#d49c17"
        readonly property color accept: "#5898be"
        readonly property color decline: "#e2576e"
        // The ○ and × marks; paper on those discs is under 2.5:1.
        readonly property color mark: "#ffffff"
        readonly property color hpHigh: "#8ec63f"
        readonly property color hpMid: "#e6c63c"
        readonly property color hpLow: "#e2576e"
        readonly property color mp: "#5898be"
        // A card's inner well, the anime's inset shadow, fading out this far in from each edge.
        readonly property color well: Qt.alpha(ink, 0.35)
        readonly property real wellFade: 0.2
        // The paper floats over the world; the anime never dims it, so a shadow keeps it readable instead.
        readonly property color shadow: Qt.rgba(0, 0, 0, 0.45)
        readonly property int shadowBlur: 24
        // HP turns yellow, then red, under these.
        readonly property real hpWarn: 0.5
        readonly property real hpDanger: 0.2
        readonly property int button: 64
        // The ring sits this far outside the disc.
        readonly property int ringGap: 4
        readonly property int ring: 2
        readonly property int gap: 20
        // The column's place: in from the left edge, and down from the bar.
        readonly property int inset: 40
        readonly property int top: 40
        readonly property int ribbon: 40
        readonly property int ribbonWidth: 180
        readonly property int ribbonTip: 16
        readonly property int panel: 380
        readonly property int panelMax: 520
        readonly property int scroll: 4
        readonly property int bar: 10
        readonly property int avatar: 72
        readonly property int dialog: 360
        readonly property int choice: 44
        readonly property int choiceMark: 18
        readonly property int choiceStroke: 4
        readonly property int choiceGap: 120
        // The focused choice grows a ring this far out.
        readonly property int choiceRing: 3
        // The drag-down strip on the left edge, how far down it reaches, and how far a drag must go.
        readonly property int edge: 4
        readonly property real edgeReach: 0.35
        readonly property int pull: 80
        // Each button drops in this long after the one above.
        readonly property int stagger: 35
        readonly property int drop: 48
        // A card swings open from this angle, like a door; the dialog flips down from the top.
        readonly property real swing: -70
        readonly property real flip: -90
    }

    // Lower damping overshoots more.
    readonly property QtObject spring: QtObject {
        readonly property real stiffness: 12
        readonly property real damping: 0.55
        // The password dots land with more bounce.
        readonly property real dotDamping: damping * 0.6
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

    function luminance(c: color): real {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function setAccent(c: color): void {
        savedAccent = c.toString();
        accentFile.setText(savedAccent);
    }

    // Ink, not black: black reads as a hole and kills the blur behind.
    function scrim(alpha: real): color {
        return Qt.rgba(bg.r, bg.g, bg.b, alpha);
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "enable-animations"]

        stdout: StdioCollector {
            onStreamFinished: root.reduceMotion = text.trim() === "false"
        }
    }

    // The program itself, not a pipeline, so a reload cannot orphan it.
    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "enable-animations"]

        stdout: SplitParser {
            onRead: line => root.reduceMotion = line.trim().endsWith("false")
        }
    }

    FileView {
        id: accentFile

        onLoaded: root.savedAccent = text().trim()

        path: Quickshell.statePath("accent.txt")
        printErrors: false
        blockWrites: false
    }
}
