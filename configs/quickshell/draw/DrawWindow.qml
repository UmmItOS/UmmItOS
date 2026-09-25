pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import ".."

OverlayWindow {
    id: win

    shown: Draw.open
    name: "draw"
    screen: Draw.screen

    readonly property var colors: [Theme.urgent, Theme.warn, Theme.good, Theme.accent2, Theme.fg]
    property int ink: 0
    property int size: 1
    property bool highlighter: false

    // Finished strokes and the one being drawn, in screen coordinates: { color, width, alpha, points }.
    property var strokes: []
    property var current: null
    property bool panning: false
    property point panFrom

    // view = screen * zoom + t.
    property real zoom: 1
    property real tx: 0
    property real ty: 0

    // Screen pixels, whatever the zoom.
    readonly property real penWidth: Theme.draw.widths[size] * (highlighter ? Theme.draw.highlightWidth : 1)

    function zoomAt(px: real, py: real, steps: real): void {
        const z = Math.max(1, Math.min(Theme.draw.zoomMax, zoom * Math.pow(Theme.draw.zoomStep, steps)));
        const w = width, h = height;
        tx = Math.max(w - w * z, Math.min(0, px - (px - tx) * z / zoom));
        ty = Math.max(h - h * z, Math.min(0, py - (py - ty) * z / zoom));
        zoom = z;
    }

    function panBy(dx: real, dy: real): void {
        tx = Math.max(width - width * zoom, Math.min(0, tx + dx));
        ty = Math.max(height - height * zoom, Math.min(0, ty + dy));
    }

    function resetZoom(): void {
        zoom = 1;
        tx = ty = 0;
    }

    function undo(): void {
        strokes = strokes.slice(0, -1);
    }

    // The view as it is now, annotations included, onto the clipboard.
    function copy(): void {
        const file = Quickshell.env("XDG_RUNTIME_DIR") + "/ummitos-draw.png";
        view.grabToImage(result => {
            result.saveToFile(file);
            Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1" && notify-send -a Draw -h string:image-path:"$1" "Copied" "The drawing is on the clipboard."', "sh", file]);
        });
    }

    onOpened: {
        // Only a closed overlay captures, or it photographs itself.
        if (!visible)
            frozen.captureFrame();
        strokes = [];
        current = null;
        zoom = 1;
        tx = ty = 0;
        scope.forceActiveFocus();
    }

    FocusScope {
        id: scope

        anchors.fill: parent
        focus: true
        opacity: Math.min(1, win.reveal)

        Keys.onEscapePressed: Draw.open = false
        Keys.onPressed: event => {
            const ctrl = event.modifiers & Qt.ControlModifier;
            if (ctrl && event.key === Qt.Key_Z)
                win.undo();
            else if (ctrl && event.key === Qt.Key_C)
                win.copy();
            else if (event.key === Qt.Key_C)
                win.strokes = [];
            else if (event.key === Qt.Key_P)
                win.highlighter = false;
            else if (event.key === Qt.Key_H)
                win.highlighter = true;
            else if (event.key === Qt.Key_0)
                win.resetZoom();
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5)
                win.ink = event.key - Qt.Key_1;
            else
                return;
            event.accepted = true;
        }

        Item {
            id: view

            anchors.fill: parent
            clip: true

            Item {
                id: stage

                width: view.width
                height: view.height
                transform: [
                    Scale {
                        xScale: win.zoom
                        yScale: win.zoom
                    },
                    Translate {
                        x: win.tx
                        y: win.ty
                    }
                ]

                ScreencopyView {
                    id: frozen
                    anchors.fill: parent
                    captureSource: Draw.screen
                    live: false
                }

                component Stroke: Shape {
                    id: stroke

                    property var model: null

                    anchors.fill: parent
                    visible: stroke.model !== null
                    opacity: stroke.model?.alpha ?? 1
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: stroke.model?.color ?? "transparent"
                        strokeWidth: stroke.model?.width ?? 1
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: stroke.model?.points ?? []
                        }
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: win.strokes
                    }

                    Stroke {
                        required property var modelData
                        model: modelData
                    }
                }

                Stroke {
                    model: win.current
                }
            }
        }

        MouseArea {
            id: area

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.BlankCursor

            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    win.panning = true;
                    win.panFrom = Qt.point(mouse.x, mouse.y);
                    return;
                }
                const p = stage.mapFromItem(area, mouse.x, mouse.y);
                // Two points, so a click leaves a dot.
                win.current = {
                    color: win.colors[win.ink],
                    width: win.penWidth / win.zoom,
                    alpha: win.highlighter ? Theme.draw.highlightAlpha : 1,
                    points: [p, Qt.point(p.x + 0.01, p.y)]
                };
            }
            onPositionChanged: mouse => {
                if (win.panning) {
                    win.panBy(mouse.x - win.panFrom.x, mouse.y - win.panFrom.y);
                    win.panFrom = Qt.point(mouse.x, mouse.y);
                } else if (win.current) {
                    const c = win.current;
                    c.points = c.points.concat([stage.mapFromItem(area, mouse.x, mouse.y)]);
                    win.current = Object.assign({}, c);
                }
            }
            onReleased: mouse => {
                if (mouse.button === Qt.RightButton) {
                    win.panning = false;
                    return;
                }
                if (win.current)
                    win.strokes = win.strokes.concat([win.current]);
                win.current = null;
            }
            onWheel: wheel => win.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y / 120)
        }

        // The pen itself, where the pointer is.
        Rectangle {
            x: area.mouseX - width / 2
            y: area.mouseY - height / 2
            width: win.penWidth
            height: width
            radius: width / 2
            color: win.colors[win.ink]
            opacity: win.highlighter ? Theme.draw.highlightAlpha : 1
            visible: area.containsMouse && !win.panning && !bar.hovered
        }

        component Tool: Rectangle {
            id: tool

            property string icon
            property bool picked
            signal clicked

            implicitWidth: Theme.control.field
            implicitHeight: Theme.control.field
            radius: Theme.rounding.full
            color: tool.picked ? Theme.accent : toolHover.hovered ? Theme.bgTray : "transparent"
            scale: toolTap.pressed ? Theme.popScale : 1

            MaterialIcon {
                anchors.centerIn: parent
                text: tool.icon
                color: Theme.fg
                size: Theme.icon.small
            }

            HoverHandler {
                id: toolHover
            }

            TapHandler {
                id: toolTap
                onTapped: tool.clicked()
            }
        }

        // Tools, bottom centre; it steps back while a stroke is being drawn.
        Surface {
            id: bar

            readonly property bool hovered: barHover.hovered

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.windowInset
            width: tools.implicitWidth + Theme.padding.medium * 2
            height: tools.implicitHeight + Theme.padding.small * 2
            radius: Theme.rounding.full
            tone: Theme.bg
            lift: 1.12
            opacity: win.current ? 0.2 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            HoverHandler {
                id: barHover
            }

            // Swallows presses, so a click on the bar never starts a stroke.
            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                id: tools

                anchors.centerIn: parent
                spacing: Theme.spacing.extraSmall

                Tool {
                    icon: "stylus"
                    picked: !win.highlighter
                    onClicked: win.highlighter = false
                }

                Tool {
                    icon: "ink_highlighter"
                    picked: win.highlighter
                    onClicked: win.highlighter = true
                }

                Item {
                    implicitWidth: Theme.spacing.medium
                }

                Repeater {
                    model: win.colors

                    Rectangle {
                        id: swatch

                        required property color modelData
                        required property int index

                        implicitWidth: Theme.control.field
                        implicitHeight: Theme.control.field
                        radius: Theme.rounding.full
                        color: win.ink === swatch.index ? Theme.bgTray : "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: win.ink === swatch.index ? Theme.icon.small : Theme.icon.tiny
                            height: width
                            radius: width / 2
                            color: swatch.modelData
                        }

                        TapHandler {
                            onTapped: win.ink = swatch.index
                        }
                    }
                }

                Item {
                    implicitWidth: Theme.spacing.medium
                }

                Repeater {
                    model: Theme.draw.widths

                    Rectangle {
                        id: dot

                        required property real modelData
                        required property int index

                        implicitWidth: Theme.control.field
                        implicitHeight: Theme.control.field
                        radius: Theme.rounding.full
                        color: win.size === dot.index ? Theme.bgTray : "transparent"

                        Rectangle {
                            anchors.centerIn: parent
                            width: dot.modelData + Theme.spacing.hair
                            height: width
                            radius: width / 2
                            color: Theme.fg
                        }

                        TapHandler {
                            onTapped: win.size = dot.index
                        }
                    }
                }

                Item {
                    implicitWidth: Theme.spacing.medium
                }

                Tool {
                    icon: "undo"
                    onClicked: win.undo()
                }

                Tool {
                    icon: "delete_sweep"
                    onClicked: win.strokes = []
                }

                Tool {
                    icon: "content_copy"
                    onClicked: win.copy()
                }

                Text {
                    Layout.preferredWidth: Theme.control.readout
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(win.zoom * 100) + "%"
                    color: win.zoom > 1 ? Theme.fg : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.features: ({
                            tnum: 1
                        })

                    TapHandler {
                        onTapped: win.resetZoom()
                    }
                }

                Tool {
                    icon: "close"
                    onClicked: Draw.open = false
                }
            }
        }
    }
}
