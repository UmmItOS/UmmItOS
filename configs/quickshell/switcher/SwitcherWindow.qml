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


    // The cards carry no labels of their own. Nine small captions compete with
    // the thing they caption; one large one, under the grid, changes as the
    // selection moves and gives the workspace a name worth reading.
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
        if (Switcher.overviewing)
            zoomFrom(1);
    }

    // The overview zooms: the current workspace's card starts filling the
    // screen and settles into the grid, and on the way out the chosen card
    // grows back to fill it. 0 is the grid, 1 is the card at full screen.
    property real zoom: 0
    property Item focusCell: null
    // Where the current card sits in the stage. A binding over the layout,
    // not a snapshot: on open the grid is still being laid out, and a
    // measurement taken then pointed the zoom at the wrong place.
    readonly property rect zoomCard: {
        const c = focusCell;
        if (!c)
            return Qt.rect(0, 0, 1, 1);
        void [c.x, c.y, c.width, c.height, c.parent?.x, c.parent?.y, grid.width, grid.height, stage.width, stage.height];
        const r = c.mapToItem(stage, 0, 0, c.width, c.height);
        return Qt.rect(r.x, r.y, Math.max(1, r.width), Math.max(1, r.height));
    }

    function zoomFrom(start: real): void {
        zoomAnim.stop();
        zoom = start;
        zoomAnim.to = start === 1 ? 0 : 1;
        zoomAnim.start();
    }

    onShownChanged: {
        if (!shown && Switcher.overviewing)
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

    // The card's rectangle, in the stage's own coordinates, between its grid
    // place and the whole screen.
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
                // release(), not commit(): the surface sees the Alt release
                // too, and going straight to commit here ignored the pin no
                // matter what the compositor's release bind did.
                Switcher.release();
                event.accepted = true;
            }
        }

        // A mouse target for the same thing P does. Holding Alt is exactly the
        // state in which a keyboard shortcut is least reachable, so pinning
        // needs something to click.
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

        // The screen as it was just before the overview opened, at full
        // resolution, laid exactly over the zoomed card. The live card is a
        // small capture, so stretched to full screen it looked like 144p; this
        // is sharp there and hands over to the card as it shrinks.
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

                // Wraps at three across, the way a Windows switcher does, so
                // cards keep a usable size instead of shrinking with every
                // workspace. Rows are built by hand rather than with a Grid so
                // a short last row sits centred under the others instead of
                // hanging off the left edge.
                readonly property int count: Math.max(1, Switcher.workspaces.length)
                // Three across, the way a Windows switcher does — but a fourth
                // column past eight workspaces, because a fourth row costs the
                // cards more height than a fourth column costs them width.
                readonly property int columns: count <= 3 ? count : count <= 8 ? 3 : 4
                readonly property int rows: Math.ceil(count / columns)

                // Cards take whatever the screen can give, capped so a lone
                // workspace does not blow up to full width. The caption block
                // is reserved first; it does not depend on the grid, so the
                // height it takes is safe to read here.
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
                                }

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Surface {
                                    id: card

                                    readonly property bool current: cell.current
                                    // Empty while unmapped: every entry is a live
                                    // capture, and they would otherwise run all day
                                    // behind a switcher nobody can see.
                                    readonly property var windows: cell.modelData && (win.visible || Switcher.warming) ? [...cell.modelData.toplevels.values].slice(0, 4) : []

                                    // The focused card grows by shrinking its inset
                                    // inside a fixed cell. Animating `scale` instead
                                    // would magnify the glow layer's texture rather
                                    // than redraw at the new size, which is what made
                                    // it look resampled — and a fixed cell means
                                    // growing does not shove its neighbours around.
                                    anchors.fill: parent
                                    anchors.margins: current ? 0 : Theme.spacing.largeIncreased
                                    radius: Theme.rounding.extraLarge
                                    tone: Theme.bgAlt

                                    // Selection is carried by light, not by paint. The
                                    // unselected cards recede; the selected one is the
                                    // only one at full strength. Filling it with accent
                                    // instead would hide the very preview it points at.
                                    // The overview marks its choice harder (the rest
                                    // step well back); Alt+Tab keeps its original look.
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

                                    // Off while zooming: a layer is rasterised at the
                                    // card's own size, so scaling it magnifies pixels.
                                    layer.enabled: card.current && win.zoom < 0.01
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Switcher.overviewing ? Theme.accentText : Theme.accent
                                        shadowBlur: 1
                                        shadowOpacity: Switcher.overviewing ? 1 : 0.75
                                        shadowVerticalOffset: 0
                                        shadowHorizontalOffset: 0
                                    }

                                    // Live captures of what is on that workspace, edge
                                    // to edge: a preview inside a padded box inside a
                                    // card is two frames too many. A workspace that is
                                    // not being rendered hands back its last frame
                                    // rather than a current one — a compositor limit,
                                    // not something the shell can fix.
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

                                                ScreencopyView {
                                                    required property HyprlandToplevel modelData

                                                    width: tiles.width / tiles.columns - 1
                                                    height: card.windows.length > 2 ? tiles.height / 2 - 1 : tiles.height
                                                    captureSource: modelData.wayland
                                                    // Twice the tile's size, shrunk smoothly by Qt: at
                                                    // exactly tile size the compositor shrank a whole
                                                    // window about 3x in one cheap step, which blurred
                                                    // and jagged the text.
                                                    constraintSize: Qt.size(width * 2, height * 2)
                                                    smooth: true
                                                    live: true
                                                    paintCursor: false
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

                                    // Window count, floated over the capture rather
                                    // than given a row of its own — it is a footnote,
                                    // and a footnote should not cost a band of card.
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
                                            text: card.windows.length
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

                                    // Only a pointer that has actually moved may
                                    // change the selection: the focused card grows,
                                    // and the geometry shifting under a still cursor
                                    // used to snap the selection back.
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
                    // Capped against the window, not the grid: measuring against the
                    // grid would make the cards depend on the caption and the
                    // caption on the cards.
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

                    // The title crossfades where the cards slide: swapping the
                    // text outright on every tab reads as a flicker at this
                    // size.
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
                    // Window count only. Hyprland names workspaces by number,
                    // and a bare number under the title is the index this
                    // switcher deliberately does not show.
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

                // Only while pinned: the switcher no longer closes by itself,
                // so it has to say how to leave.
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // Hidden by opacity, not visibility: its line is always
                    // reserved, or pinning would shrink every card to make room.
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

    // The hot corner answering: rings of light spread from the top-left
    // corner when it fires, so the push is seen to have landed.
    Item {
        id: cornerRipple

        property real t: 1

        anchors.fill: parent
        visible: t < 1

        Connections {
            target: Switcher

            function onCornerHitsChanged(): void {
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
