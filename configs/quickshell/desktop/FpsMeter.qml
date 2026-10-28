pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import ".."

// A frame-rate counter in the corner, switched like cl_showfps: `ipc call fps set 1|0` or toggle.
Scope {
    IpcHandler {
        function toggle(): void {
            Settings.setFps(!Settings.fpsShow);
        }

        function set(on: int): void {
            Settings.setFps(on !== 0);
        }

        target: "fps"
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            property real shown: Settings.fpsShow ? 1 : 0
            property int fps: 0
            // Frames this window has swapped, and the count and wall-clock time at the last reading.
            property int swaps: 0
            property int mark: 0
            property real markTime: 0

            screen: modelData
            visible: shown > 0
            // Bottom, with the weather card: windows and every shell surface cover it.
            WlrLayershell.namespace: "ummitos-fps"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                left: true
            }

            margins {
                top: Theme.barHeight + Theme.windowInset
                left: Theme.windowInset
            }

            implicitWidth: pill.width
            implicitHeight: pill.height
            color: "transparent"
            // Clicks go to what is under it.
            mask: Region {}

            Behavior on shown {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            // Counts frames really swapped: FrameAnimation's own ticks follow Qt's timer and ran past the refresh rate.
            Connections {
                function onFrameSwapped(): void {
                    win.swaps++;
                }

                target: Settings.fpsShow ? pill.Window.window : null
            }

            // Redraws every tick so a frame is swapped each time the compositor allows one.
            FrameAnimation {
                running: Settings.fpsShow
                onTriggered: pill.Window.window?.update()
            }

            Timer {
                interval: Theme.fps.interval
                running: Settings.fpsShow
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    const now = Date.now();
                    const n = win.swaps;
                    if (win.markTime > 0 && now > win.markTime)
                        win.fps = Math.round((n - win.mark) * 1000 / (now - win.markTime));
                    win.mark = n;
                    win.markTime = now;
                }
                onRunningChanged: win.markTime = 0
            }

            // The weather card's material and type, so it reads as one of the desktop widgets.
            Rectangle {
                id: pill

                width: row.implicitWidth + 2 * Theme.spacing.large
                height: row.implicitHeight + 2 * Theme.spacing.medium
                radius: Theme.rounding.extraLarge
                color: Theme.scrim(Theme.panelTint)
                opacity: win.shown
                layer.enabled: win.shown < 1

                layer.effect: MotionBlur {
                    settled: win.shown
                }

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: Theme.spacing.small

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "speed"
                        color: Theme.accentText
                        fill: 1
                        size: Theme.icon.normal
                    }

                    Text {
                        anchors.baseline: unit.baseline
                        textFormat: Text.PlainText
                        text: win.fps
                        color: Theme.fg
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.extraLarge
                        font.weight: Font.Light

                        font.features: ({
                                tnum: 1
                            })
                    }

                    Text {
                        id: unit

                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: I18n.t("FPS")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                    }
                }
            }
        }
    }
}
