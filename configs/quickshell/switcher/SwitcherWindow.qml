pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
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

    // The pointer is wherever it was left. Without this, opening the switcher
    // fires onEntered on whatever card happens to be under it, which overwrites
    // the keyboard selection the moment it is computed — every Alt+Tab landed
    // on the card beneath the cursor instead of the next workspace.
    property bool pointerArmed: false

    onVisibleChanged: {
        if (visible) {
            pointerArmed = false;
            arm.restart();
            scope.forceActiveFocus();
        }
    }

    // Qt delivers a position event when an area appears under a stationary
    // cursor, so "has the pointer moved" cannot be answered from events alone.
    // Ignoring hover for a moment after opening is deterministic.
    Timer {
        id: arm
        interval: 250
        onTriggered: win.pointerArmed = true
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

        Grid {
            id: grid
            anchors.centerIn: parent
            spacing: Theme.spacing.large

            // Wraps at three across, the way a Windows switcher does, so cards
            // keep a usable size instead of shrinking with every workspace.
            readonly property int count: Math.max(1, Switcher.workspaces.length)
            columns: Math.min(3, count)
            readonly property int cellWidth: Math.min(520, (win.width - Theme.padding.extraLarge * 4) / columns - spacing)
            readonly property int cellHeight: cellWidth * 0.68

            Repeater {
                model: Switcher.workspaces

                Item {
                    id: cell
                    required property HyprlandWorkspace modelData
                    required property int index

                    readonly property bool current: Switcher.index === index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    Surface {
                    id: card

                    readonly property bool current: cell.current
                    readonly property var modelData: cell.modelData
                    readonly property var windows: cell.modelData ? [...cell.modelData.toplevels.values].slice(0, 4) : []

                    // The focused card grows by shrinking its inset inside a
                    // fixed cell. Animating `scale` instead would magnify the
                    // glow layer's texture rather than redraw at the new size,
                    // which is what made it look resampled — and a fixed cell
                    // means growing does not shove its neighbours around.
                    anchors.fill: parent
                    anchors.margins: current ? 0 : Theme.spacing.largeIncreased
                    radius: Theme.rounding.extraLarge
                    tone: current ? Theme.accent : Theme.bgAlt

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
                        shadowOpacity: 0.55
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    ColumnLayout {
                        anchors {
                            fill: parent
                            margins: Theme.padding.medium
                        }
                        spacing: Theme.spacing.small

                        // Live captures of what is on that workspace. A
                        // workspace that is not being rendered hands back its
                        // last frame rather than a current one — that is a
                        // compositor limit, not something the shell can fix.
                        ClippingRectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.rounding.medium
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
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.smaller
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.small

                            Text {
                                Layout.fillWidth: true
                                // The focused window names the workspace; an
                                // index says nothing about what is on it.
                                text: {
                                    if (!card.modelData)
                                        return "";
                                    const all = card.modelData.toplevels.values;
                                    if (all.length === 0)
                                        return "Empty";
                                    const top = all.find(w => w.activated) ?? all[0];
                                    return top.title === "" ? card.modelData.name : top.title;
                                }
                                color: Theme.fg
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSize.smaller
                                font.weight: Theme.weight.bold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: card.modelData ? card.modelData.toplevels.values.length : 0
                                color: card.current ? Theme.fg : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                                font.features: ({
                                        tnum: 1
                                    })
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true

                        onPositionChanged: {
                            if (win.pointerArmed)
                                Switcher.index = cell.index;
                        }
                        onEntered: {
                            if (win.pointerArmed)
                                Switcher.index = cell.index;
                        }
                        onClicked: Switcher.commit()
                    }
                    }
                }
            }
        }
    }
}
