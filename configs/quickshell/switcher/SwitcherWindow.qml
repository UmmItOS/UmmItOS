pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."

PanelWindow {
    id: win

    visible: Switcher.open

    WlrLayershell.namespace: "ummitos-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // Focus is the point: with it, the Alt release arrives here as a key event,
    // so the switcher can commit when the modifier is let go.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.scrim(0.45)

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

    // Only a pointer that has actually moved may change the selection.
    //
    // Enter events are not evidence of movement: they fire when the switcher
    // opens under a stationary cursor, and again every time the selection
    // changes, because the focused card grows and the geometry shifts beneath
    // the pointer. Acting on them made the selection snap back to whichever
    // card sat under the mouse, which looked like the switcher refusing to
    // advance. The last known position is compared instead, in window
    // coordinates so card-local movement from a resize does not count.
    property point lastPointer: Qt.point(-1, -1)

    onVisibleChanged: {
        if (visible) {
            lastPointer = Qt.point(-1, -1);
            scope.forceActiveFocus();
        }
    }

    FocusScope {
        id: scope
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
            } else if (event.key === Qt.Key_Escape) {
                Switcher.cancel();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Switcher.commit();
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
                Switcher.commit();
                event.accepted = true;
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacing.extraLarge

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

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Surface {
                                    id: card

                                    readonly property bool current: cell.current
                                    readonly property var windows: cell.modelData ? [...cell.modelData.toplevels.values].slice(0, 4) : []

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
                                    opacity: current ? 1 : 0.5

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

                                    layer.enabled: card.current
                                    layer.effect: MultiEffect {
                                        shadowEnabled: true
                                        shadowColor: Theme.accent
                                        shadowBlur: 1
                                        shadowOpacity: 0.75
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
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.fontSize.large
                                            font.letterSpacing: Theme.tracking.wider
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
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize.normal
                                            font.weight: Theme.weight.medium
                                            font.features: ({
                                                tnum: 1
                                            })
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true

                                    onPositionChanged: mouse => {
                                        const p = mapToItem(null, mouse.x, mouse.y);
                                        const first = win.lastPointer.x < 0;
                                        const moved = Math.abs(p.x - win.lastPointer.x) > 2 || Math.abs(p.y - win.lastPointer.y) > 2;
                                        win.lastPointer = p;
                                        if (!first && moved)
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
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.weight: Theme.weight.bold
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
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    font.weight: Theme.weight.medium
                    font.letterSpacing: Theme.tracking.wider
                }
            }
        }
    }
}

