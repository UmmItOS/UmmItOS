pragma ComponentBehavior: Bound

import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    // Where the cursor was when the sheet opened, for the light until it moves (window coordinates; -1 is unknown).
    property point seed: Qt.point(-1, -1)

    // A bind's description in the chosen language; numbered ones ("1–10" once merged) share one template.
    function said(text: string): string {
        const n = text.match(/^(.*workspace) ([\d–-]+)$/);
        return n ? I18n.t(n[1] + " %1").arg(n[2]) : I18n.t(text);
    }

    onOpened: {
        scope.forceActiveFocus();
        win.seed = Qt.point(-1, -1);
        cursor.running = true;
    }

    shown: Cheatsheet.open
    name: "cheatsheet"
    scrim: Theme.shade.normal

    // A key, drawn as a key.
    component Keycap: Rectangle {
        required property string label

        implicitWidth: Math.max(implicitHeight, text.implicitWidth + Theme.spacing.small * 2)
        implicitHeight: text.implicitHeight + Theme.spacing.extraSmall * 2
        radius: Theme.rounding.extraSmall
        color: Theme.bgTray

        Text {
            id: text

            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: parent.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.weight: Theme.weight.medium
        }
    }

    // Hyprland's cursor position is in layout coordinates: take this screen's origin off.
    Process {
        id: cursor

        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [x, y] = text.trim().split(",").map(Number);
                if (!isNaN(x) && !isNaN(y))
                    win.seed = Qt.point(x - (win.screen?.x ?? 0), y - (win.screen?.y ?? 0));
            }
        }
    }

    MouseArea {
        onClicked: Cheatsheet.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

        Keys.onEscapePressed: Cheatsheet.open = false

        anchors.centerIn: parent
        width: Math.min(Theme.cheatsheet.width, parent.width - Theme.spacing.extraLarge * 2)
        height: Math.min(sheet.implicitHeight, parent.height - Theme.spacing.extraLarge * 2)
        focus: true
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        // Clicks on the sheet stay on the sheet.
        MouseArea {
            anchors.fill: parent
        }

        // The window border's gradient, turning, cut to an outline by a mask.
        Item {
            id: ringFill

            anchors {
                fill: sheet
                margins: -ring.thickness
            }

            visible: false
            layer.enabled: true
            clip: true

            Rectangle {
                anchors.centerIn: parent
                width: Math.hypot(parent.width, parent.height)
                height: width

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Theme.ring[0]
                    }

                    GradientStop {
                        position: 0.33
                        color: Theme.ring[1]
                    }

                    GradientStop {
                        position: 0.66
                        color: Theme.ring[2]
                    }

                    GradientStop {
                        position: 1
                        color: Theme.ring[3]
                    }
                }

                RotationAnimation on rotation {
                    running: win.visible
                    from: 0
                    to: 360
                    duration: Theme.duration.ringTurn
                    loops: Animation.Infinite
                }
            }
        }

        // The ring's source is hidden, so its turning draws no frames of its own: this near-invisible pulse asks for them.
        Rectangle {
            width: 1
            height: 1
            color: "white"
            opacity: 0.01

            NumberAnimation on opacity {
                running: win.visible
                from: 0.01
                to: 0.02
                duration: Theme.duration.ringTurn
                loops: Animation.Infinite
            }
        }

        // The outline the gradient shows through; a mask, never drawn.
        Rectangle {
            id: ring

            readonly property int thickness: Theme.cheatsheet.ring

            anchors.fill: ringFill
            visible: false
            layer.enabled: true
            radius: sheet.radius + ring.thickness
            color: "transparent"
            border.width: ring.thickness
            border.color: "white"
        }

        MultiEffect {
            id: ringLine

            anchors.fill: ringFill
            source: ringFill
            maskEnabled: true
            maskSource: ring
        }

        // Captured with padding, or the blur stops at the ring's edge.
        ShaderEffectSource {
            id: lineShot

            readonly property int pad: Theme.cheatsheet.glowPad

            sourceItem: ringLine
            sourceRect: Qt.rect(-pad, -pad, ringLine.width + pad * 2, ringLine.height + pad * 2)
            width: sourceRect.width
            height: sourceRect.height
            visible: false
        }

        MultiEffect {
            z: -1

            anchors {
                fill: ringFill
                margins: -lineShot.pad
            }

            source: lineShot
            blurEnabled: true
            blurMax: lineShot.pad
            blur: 1
            brightness: Theme.cheatsheet.glowBrightness
            saturation: Theme.cheatsheet.glowSaturation
        }

        Item {
            id: fillMask

            anchors.fill: ringFill
            visible: false
            layer.enabled: true

            Rectangle {
                anchors {
                    fill: parent
                    margins: ring.thickness
                }

                radius: sheet.radius
                color: "white"
            }
        }

        MultiEffect {
            anchors.fill: ringFill
            source: ringFill
            maskEnabled: true
            maskSource: fillMask
            opacity: Theme.cheatsheet.ringOpacity
        }

        Surface {
            id: sheet

            anchors.fill: parent
            implicitHeight: body.implicitHeight + Theme.spacing.extraLarge * 2
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: Theme.lift.sheet

            HoverHandler {
                id: pointer
            }

            // A plain clip is square and lights the empty corners.
            ClippingRectangle {
                anchors.fill: parent
                radius: sheet.radius
                color: "transparent"

                Item {
                    id: spot

                    readonly property int size: Theme.cheatsheet.spot

                    width: spot.size
                    height: spot.size
                    readonly property point at: pointer.hovered ? pointer.point.position : sheet.mapFromItem(win.contentItem, win.seed.x, win.seed.y)
                    readonly property bool lit: pointer.hovered || (win.seed.x >= 0 && at.x >= 0 && at.y >= 0 && at.x <= sheet.width && at.y <= sheet.height)

                    x: at.x - spot.size / 2
                    y: at.y - spot.size / 2
                    opacity: lit ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.emphasizedDecel
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    // Fades to zero before its edge, so it reads as light, not a shape.
                    Canvas {
                        id: glow

                        onPaint: {
                            const ctx = getContext("2d");
                            const r = width / 2;
                            const c = Theme.accentText;
                            const g = ctx.createRadialGradient(r, r, 0, r, r, r);
                            g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, Theme.cheatsheet.spotCore));
                            g.addColorStop(Theme.cheatsheet.spotEdgeAt, Qt.rgba(c.r, c.g, c.b, Theme.cheatsheet.spotEdge));
                            g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = g;
                            ctx.fillRect(0, 0, width, height);
                        }

                        anchors.fill: parent

                        Connections {
                            function onAccentTextChanged(): void {
                                glow.requestPaint();
                            }

                            target: Theme
                        }
                    }
                }
            }

            Flickable {
                anchors {
                    fill: parent
                    margins: Theme.spacing.extraLarge
                }

                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: body

                    width: parent.width
                    spacing: Theme.spacing.large

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            Layout.fillWidth: true
                            text: I18n.t("Cheat sheet")
                            color: Theme.fg
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.extraLarge
                            font.bold: true
                        }

                        MaterialIcon {
                            text: "close"
                            color: Theme.dim
                            size: Theme.icon.small

                            TapHandler {
                                onTapped: Cheatsheet.open = false
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor(width / Theme.cheatsheet.column))
                        columnSpacing: Theme.spacing.extraLarge
                        rowSpacing: Theme.spacing.extraLarge

                        Repeater {
                            model: Cheatsheet.groups

                            ColumnLayout {
                                id: group

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: Theme.spacing.small

                                Text {
                                    textFormat: Text.PlainText
                                    text: I18n.t(group.modelData.title)
                                    color: Theme.accentText
                                    font.family: Theme.fontDisplay
                                    font.pixelSize: Theme.fontSize.large
                                    font.bold: true
                                }

                                Repeater {
                                    model: group.modelData.rows

                                    RowLayout {
                                        id: row

                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: Theme.spacing.medium

                                        Row {
                                            Layout.preferredWidth: Theme.cheatsheet.keys
                                            spacing: Theme.spacing.extraSmall

                                            Repeater {
                                                model: row.modelData.keys

                                                Keycap {
                                                    required property string modelData

                                                    label: modelData
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            textFormat: Text.PlainText
                                            text: win.said(row.modelData.description)
                                            color: Theme.fg
                                            wrapMode: Text.Wrap
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize.normal
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
