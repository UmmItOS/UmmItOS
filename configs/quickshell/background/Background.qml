pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        WlrLayershell.namespace: "ummitos-background"
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "black"

        // Crossfade adapted from caelestia-dots/shell (GPL-3.0): each change
        // stacks a new Image on top, fades it in once it has loaded, then
        // destroys the one underneath. Their Anim.SlowEffects timing.
        Item {
            id: fader
            anchors.fill: parent

            readonly property int duration: Theme.duration.expressiveSlowEffects
            property Image currentImage

            Component.onCompleted: swap(Wallpapers.current)

            Connections {
                target: Wallpapers
                function onCurrentChanged() {
                    fader.swap(Wallpapers.current);
                }
            }

            function swap(path: string): void {
                if (!path)
                    return;
                currentImage = imgComp.createObject(fader, {
                    source: "file://" + path
                });
            }

            Component {
                id: imgComp

                Image {
                    id: img

                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: 0
                    // Decoding a 4K wallpaper at full size for a 1080p screen
                    // costs several frames. 1.25x leaves room for the crop.
                    sourceSize.width: fader.width * 1.25
                    sourceSize.height: fader.height * 1.25

                    onStatusChanged: {
                        if (status === Image.Ready)
                            fade.start();
                    }

                    NumberAnimation on opacity {
                        id: fade
                        running: false
                        from: 0
                        to: 1
                        duration: fader.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveSlowEffects
                    }

                    Timer {
                        running: fader.currentImage !== img && (fader.currentImage?.status ?? Image.Null) === Image.Ready
                        interval: fader.duration
                        onTriggered: img.destroy()
                    }
                }
            }
        }
    }
}
