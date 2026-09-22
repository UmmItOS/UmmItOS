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

    onVisibleChanged: {
        if (visible)
            scope.forceActiveFocus();
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

        RowLayout {
            id: cards
            anchors.centerIn: parent
            spacing: Theme.spacing.largeIncreased

            // Cards take what the screen allows, so more workspaces shrink them
            // rather than running off the edge.
            readonly property int cardWidth: Math.min(460, (win.width - Theme.padding.extraLarge * 4) / Math.max(1, Switcher.workspaces.length) - Theme.spacing.largeIncreased)

            Repeater {
                model: Switcher.workspaces

                Surface {
                    id: card
                    required property HyprlandWorkspace modelData
                    required property int index

                    readonly property bool current: Switcher.index === index
                    readonly property var windows: [...modelData.toplevels.values].slice(0, 4)

                    implicitWidth: cards.cardWidth
                    implicitHeight: cards.cardWidth * 0.72
                    radius: Theme.rounding.extraLarge
                    tone: current ? Theme.accent : Theme.bgAlt

                    // No scale on the focused card: it is already inside a layer
                    // for the glow, and magnifying that texture is what made the
                    // previews look resampled. Colour and glow carry focus.

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
                                text: card.modelData.toplevels.values.length
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
                        onEntered: Switcher.index = card.index
                        onClicked: Switcher.commit()
                    }
                }
            }
        }
    }
}
