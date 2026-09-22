pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
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
            // The circle takes its time, like awww's did; a fade that long drags.
            readonly property int revealDuration: Theme.duration.extraLarge * 2
            property Item currentImage

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
                const comp = Wallpapers.reveal ? revealComp : imgComp;
                Wallpapers.reveal = false;
                currentImage = comp.createObject(fader, {
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
                        interval: fader.currentImage?.transition ?? fader.duration
                        onTriggered: img.destroy()
                    }

                    readonly property int transition: fader.duration
                }
            }

            // awww's circle: the new wallpaper shows through a disc that grows
            // from near the top-right corner until it covers the screen. The
            // image inside is held still against the screen while the disc
            // moves, so it is uncovered, not slid in.
            Component {
                id: revealComp

                ClippingRectangle {
                    id: disc

                    property alias source: pic.source
                    readonly property int status: pic.status
                    readonly property int transition: fader.revealDuration
                    property real progress: 0

                    readonly property real originX: fader.width * 0.977
                    readonly property real originY: fader.height * 0.031
                    // Far enough to reach the opposite corner.
                    readonly property real reach: Math.hypot(originX, fader.height - originY)

                    width: reach * 2 * progress
                    height: width
                    radius: width / 2
                    x: originX - width / 2
                    y: originY - height / 2
                    color: "transparent"

                    Image {
                        id: pic

                        x: -disc.x
                        y: -disc.y
                        width: fader.width
                        height: fader.height
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize.width: fader.width * 1.25
                        sourceSize.height: fader.height * 1.25

                        onStatusChanged: {
                            if (status === Image.Ready)
                                grow.start();
                        }
                    }

                    NumberAnimation on progress {
                        id: grow
                        running: false
                        from: 0
                        to: 1
                        duration: fader.revealDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }

                    Timer {
                        running: fader.currentImage !== disc && (fader.currentImage?.status ?? Image.Null) === Image.Ready
                        interval: fader.currentImage?.transition ?? fader.duration
                        onTriggered: disc.destroy()
                    }
                }
            }
        }
    }
}
