pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
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
            readonly property real refresh: Hyprland.monitorFor(modelData)?.lastIpcObject?.refreshRate ?? 0
            readonly property real ratio: refresh > 0 ? fps / refresh : -1
            readonly property color tone: ratio < 0 ? Theme.fg : ratio >= Theme.fps.good ? Theme.good : ratio >= Theme.fps.warn ? Theme.warn : Theme.urgent

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

            // Frames tick only while the counter shows; a running one keeps the window rendering.
            FrameAnimation {
                id: frames

                running: Settings.fpsShow
            }

            // Reads the frame time a few times a second so the number can be read.
            Timer {
                interval: Theme.fps.interval
                running: Settings.fpsShow
                repeat: true
                triggeredOnStart: true
                onTriggered: win.fps = frames.smoothFrameTime > 0 ? Math.round(1 / frames.smoothFrameTime) : 0
            }

            Rectangle {
                id: pill

                width: label.implicitWidth + 2 * Theme.spacing.medium
                height: label.implicitHeight + 2 * Theme.spacing.small
                radius: Theme.rounding.medium
                color: Theme.scrim(Theme.panelTint)
                opacity: win.shown
                layer.enabled: win.shown < 1

                layer.effect: MotionBlur {
                    settled: win.shown
                }

                Text {
                    id: label

                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: I18n.t("%1 FPS").arg(win.fps)
                    color: win.tone
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium

                    font.features: ({
                            tnum: 1
                        })

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }
            }
        }
    }
}
