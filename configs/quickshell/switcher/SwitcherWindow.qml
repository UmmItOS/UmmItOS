pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."

OverlayWindow {
    id: win

    shown: Switcher.open
    name: "switcher"
    scrim: 0.45

    function titleOf(ws: var): string {
        if (!ws)
            return "";
        const all = [...ws.toplevels.values];
        if (all.length === 0)
            return "Empty";
        const top = all.find(w => w.activated) ?? all[0];
        return top.title === "" ? ws.name : top.title;
    }

    onOpened: {
        scope.forceActiveFocus();
        // Reset, or the next Alt+Tab opens as one giant card.
        zoomAnim.stop();
        if (Switcher.overviewing) {
            zoom = 1;
            Qt.callLater(() => zoomFrom(1));
        } else {
            zoom = 0;
            // A stale overview picture must not cover Alt+Tab's zoom.
            Switcher.startIndex = -1;
        }
    }

    // 0 is the grid, 1 the card at full screen.
    property real zoom: 0
    property Item focusCell: null
    property rect zoomCard: Qt.rect(0, 0, 1, 1)

    // Called a frame late, once the grid is laid out.
    function zoomFrom(start: real): void {
        const c = focusCell;
        if (c) {
            const r = c.mapToItem(stage, 0, 0, c.width, c.height);
            zoomCard = Qt.rect(r.x, r.y, Math.max(1, r.width), Math.max(1, r.height));
        }
        zoomAnim.stop();
        zoom = start;
        zoomAnim.to = start === 1 ? 0 : 1;
        zoomAnim.start();
    }

    onShownChanged: {
        if (!shown)
            zoomFrom(0);
    }

    NumberAnimation {
        id: zoomAnim
        target: win
        property: "zoom"
        duration: Theme.duration.expressiveDefaultSpatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curve.emphasizedDecel
    }

    readonly property real zoomW: zoomCard.width + ((win.screen?.width ?? width) - zoomCard.width) * zoom
    readonly property real zoomScale: zoomW / zoomCard.width
    readonly property real zoomX: zoomCard.x + (-stage.x - zoomCard.x) * zoom
    readonly property real zoomY: zoomCard.y + (-stage.y - zoomCard.y) * zoom

    FocusScope {
        id: scope
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) {
                Switcher.step(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                Switcher.step(1);
            } else if (event.key === Qt.Key_Left) {
                Switcher.step(-1);
            } else if (event.key === Qt.Key_Down) {
                Switcher.step(grid.columns);
            } else if (event.key === Qt.Key_Up) {
                Switcher.step(-grid.columns);
            } else if (event.key === Qt.Key_P || event.key === Qt.Key_Space) {
                // Hold it on screen; the Alt release stops closing it.
                Switcher.pinned = !Switcher.pinned;
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                Switcher.cancel();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Switcher.commit();
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                // release(), not commit(): it respects the pin.
                Switcher.release();
                event.accepted = true;
            }
        }

        // Holding Alt, a click is easier than a key.
        Surface {
            id: pin

            opacity: 1 - win.zoom
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Theme.padding.extraLarge
            implicitWidth: pinRow.implicitWidth + Theme.padding.large * 2
            implicitHeight: Theme.control.pill
            radius: Theme.rounding.full
            tone: Switcher.pinned ? Theme.accent : Theme.bgTray

            Behavior on tone {
                ColorAnimation {
                    duration: Theme.duration.expressiveFastEffects
                }
            }

            Row {
                id: pinRow
                anchors.centerIn: parent
                spacing: Theme.spacing.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "push_pin"
                    color: Theme.fg
                    fill: Switcher.pinned ? 1 : 0
                    size: Theme.icon.small
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Switcher.pinned ? "Pinned" : "Keep open"
                    color: Theme.fg
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.normal
                        weight: Theme.weight.medium
                        letterSpacing: Theme.tracking.wide
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Switcher.pinned = !Switcher.pinned
            }
        }

        // Full-resolution picture over the zoomed card; the live one is small.
        Image {
            x: stage.x + win.zoomX
            y: stage.y + win.zoomY
            width: win.zoomCard.width * win.zoomScale
            height: win.zoomCard.height * win.zoomScale
            z: 1
            source: Switcher.shotReady ? Switcher.shotUrl : ""
            cache: false
            // Decoded off the UI thread while the overview waits to open.
            asynchronous: true
            onStatusChanged: {
                if (status === Image.Ready || status === Image.Error)
                    Switcher.reveal();
            }
            fillMode: Image.PreserveAspectCrop
            visible: win.zoom > 0 && Switcher.index === Switcher.startIndex
            opacity: Math.min(1, win.zoom * 1.6)
        }

        Column {
            id: stage

            anchors.centerIn: parent
            spacing: Theme.spacing.extraLarge

            transform: [
                Scale {
                    xScale: win.zoomScale
                    yScale: win.zoomScale
                },
                Translate {
                    x: win.zoomX - win.zoomCard.x * win.zoomScale
                    y: win.zoomY - win.zoomCard.y * win.zoomScale
                }
            ]

            Column {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing.large

                // Rows by hand, so a short last row is centred.
                readonly property int count: Math.max(1, Switcher.workspaces.length)
                // A fourth column past eight costs less than a fourth row.
                readonly property int columns: count <= 3 ? count : count <= 8 ? 3 : 4
                readonly property int rows: Math.ceil(count / columns)

                readonly property int roomWide: (win.width - Theme.padding.extraLarge * 4) / columns - spacing
                readonly property int roomTall: (win.height - caption.implicitHeight - Theme.spacing.extraLarge * 3 - Theme.padding.extraLarge * 2) / rows - spacing
                readonly property int cellWidth: Math.min(620, roomWide, roomTall / 0.62)
                readonly property int cellHeight: cellWidth * 0.62

                Repeater {
                    model: grid.rows

                    Row {
                        id: cardRow
                        required property int index

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacing.large

                        Repeater {
                            model: Switcher.workspaces.slice(cardRow.index * grid.columns, (cardRow.index + 1) * grid.columns)

                            Item {
                                id: cell
                                required property HyprlandWorkspace modelData
                                required property int index

                                readonly property int slot: cardRow.index * grid.columns + index
                                readonly property bool current: Switcher.index === slot

                                Binding {
                                    target: win
                                    property: "focusCell"
                                    value: cell
                                    when: cell.current
                                    // Two cells swap in no set order.
                                    restoreMode: Binding.RestoreNone
                                }

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Surface {
                                    id: card

                                    readonly property bool current: cell.current
                                    // Empty while unmapped: each entry is a live capture.
                                    readonly property var windows: cell.modelData && (win.visible || Switcher.warming) ? [...cell.modelData.toplevels.values].slice(0, 4) : []

                                    // Grows by its inset, not `scale`, which magnified the glow layer.
                                    anchors.fill: parent
                                    anchors.margins: current ? 0 : Theme.spacing.largeIncreased
                                    radius: Theme.rounding.extraLarge
                                    tone: Theme.bgAlt

                                    opacity: current ? 1 : Switcher.overviewing ? 0.35 : 0.5

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.duration.expressiveDefaultEffects
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Theme.curve.expressiveDefaultEffects
                                        }
                                    }

                                    Behavior on anchors.margins {
                                        NumberAnimation {
                                            duration: Theme.duration.expressiveFastSpatial
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                                        }
                                    }

                                    // Off while zooming: a scaled layer magnifies pixels.
                                    layer.enabled: card.current && win.zoom < 0.01
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Switcher.overviewing ? Theme.accentText : Theme.accent
                                        shadowBlur: 1
                                        shadowOpacity: Switcher.overviewing ? 1 : 0.75
                                        shadowVerticalOffset: 0
                                        shadowHorizontalOffset: 0
                                    }

                                    // An unrendered workspace returns its last frame; a compositor limit.
                                    ClippingRectangle {
                                        anchors.fill: parent
                                        anchors.margins: Theme.padding.small
                                        radius: card.radius - Theme.padding.small
                                        color: Theme.scrim(0.45)

                                        Grid {
                                            id: tiles
                                            anchors.fill: parent
                                            columns: card.windows.length > 1 ? 2 : 1
                                            spacing: 2

                                            Repeater {
                                                model: card.windows

                                                // Mipmapped, or a 3x shrink leaves text soft.
                                                Item {
                                                    id: tile

                                                    required property HyprlandToplevel modelData

                                                    width: tiles.width / tiles.columns - 1
                                                    height: card.windows.length > 2 ? tiles.height / 2 - 1 : tiles.height

                                                    ScreencopyView {
                                                        id: view

                                                        anchors.fill: parent
                                                        captureSource: tile.modelData.wayland
                                                        live: true
                                                        paintCursor: false
                                                    }

                                                    ShaderEffectSource {
                                                        anchors.fill: parent
                                                        sourceItem: view
                                                        hideSource: true
                                                        mipmap: true
                                                        smooth: true
                                                        textureSize: view.hasContent ? view.sourceSize : Qt.size(width, height)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: card.windows.length === 0
                                            text: "Empty"
                                            color: Theme.dim
                                            font {
                                                family: Theme.fontDisplay
                                                pixelSize: Theme.fontSize.large
                                                letterSpacing: Theme.tracking.wider
                                            }
                                        }
                                    }

                                    Surface {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: Theme.spacing.medium
                                        visible: card.windows.length > 1
                                        width: Math.max(height, countText.implicitWidth + Theme.padding.medium * 2)
                                        height: countText.implicitHeight + Theme.padding.small
                                        radius: Theme.rounding.full
                                        tone: Theme.bgTray

                                        Text {
                                            id: countText
                                            anchors.centerIn: parent
                                            text: cell.modelData?.toplevels.values.length ?? 0
                                            color: Theme.fg
                                            font {
                                                family: Theme.font
                                                pixelSize: Theme.fontSize.normal
                                                weight: Theme.weight.medium
                                                features: ({
                                                    tnum: 1
                                                })
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    // Only real pointer movement changes the selection.
                                    onPositionChanged: mouse => {
                                        if (win.pointerMoved(this, mouse.x, mouse.y))
                                            Switcher.index = cell.slot;
                                    }
                                    onClicked: Switcher.commit()
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: caption
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacing.extraSmall

                readonly property var ws: Switcher.workspaces[Switcher.index] ?? null

                Text {
                    id: captionTitle
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Against the window, not the grid, to avoid a cycle.
                    width: Math.min(implicitWidth, win.width * 0.7)
                    horizontalAlignment: Text.AlignHCenter
                    text: win.titleOf(caption.ws)
                    color: Theme.fg
                    font {
                        family: Theme.fontDisplay
                        pixelSize: Theme.fontSize.extraLarge
                        weight: Theme.weight.bold
                    }
                    elide: Text.ElideRight

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation {
                                target: captionTitle
                                property: "opacity"
                                to: 0
                                duration: Theme.duration.expressiveFastEffects / 2
                            }
                            PropertyAction {}
                            NumberAnimation {
                                target: captionTitle
                                property: "opacity"
                                to: 1
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const ws = caption.ws;
                        if (!ws)
                            return "";
                        const n = ws.toplevels.values.length;
                        return n === 1 ? "1 window" : n + " windows";
                    }
                    color: Theme.accentText
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.normal
                        weight: Theme.weight.medium
                        letterSpacing: Theme.tracking.wider
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Opacity, not visibility, so the line stays reserved.
                    opacity: Switcher.pinned ? 1 : 0
                    text: "Pinned  ·  Enter to switch  ·  Esc to close"
                    color: Theme.dim
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.small
                        letterSpacing: Theme.tracking.wider
                    }
                }
            }
        }
    }

    Item {
        id: cornerRipple

        property real t: 1

        anchors.fill: parent
        visible: t < 1

        Connections {
            target: Switcher

            function onCornerHit(): void {
                rippleAnim.restart();
            }
        }

        NumberAnimation {
            id: rippleAnim
            target: cornerRipple
            property: "t"
            from: 0
            to: 1
            duration: Theme.duration.extraLarge
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curve.standardDecel
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index

                // Each ring a step behind the one before.
                readonly property real k: Math.max(0, Math.min(1, cornerRipple.t * 1.4 - index * 0.2))

                x: -width / 2
                y: -height / 2
                width: Theme.spacing.extraLarge * 12 * k
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Theme.spacing.extraSmall * (1 - k) + 1
                border.color: Theme.accentText
                opacity: (1 - k) * 0.9
            }
        }
    }
}
