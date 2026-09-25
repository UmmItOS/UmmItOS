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

        // Crossfade adapted from caelestia-dots/shell (GPL-3.0).
        Item {
            id: fader
            anchors.fill: parent

            readonly property int duration: Theme.duration.expressiveSlowEffects
            // awww's --transition-duration 2.5.
            readonly property int revealDuration: 2500
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
                const reveal = Wallpapers.reveal;
                const mode = !reveal ? "" : Math.random() < 0.5 ? "center" : ["grow", "wipe", "fade"][Math.floor(Math.random() * 3)];
                const props = {
                    source: "file://" + path
                };
                if (reveal)
                    props.mode = mode;
                currentImage = (reveal ? revealComp : imgComp).createObject(fader, props);
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
                    // A full-size 4K decode costs frames; 1.25x leaves room for the crop.
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

            // awww-style transitions; the image stays still while the shape moves.
            Component {
                id: revealComp

                ClippingRectangle {
                    id: disc

                    property alias source: pic.source
                    readonly property int status: pic.status
                    readonly property int transition: fader.revealDuration
                    property real progress: 0
                    property string mode: "grow"

                    readonly property bool round: mode === "grow" || mode === "center"
                    // awww measures y from the bottom, so 0.969 is near the top.
                    readonly property real originX: mode === "center" ? fader.width / 2 : fader.width * 0.977
                    readonly property real originY: mode === "center" ? fader.height / 2 : fader.height * (1 - 0.969)
                    // Far enough to reach the farthest corner.
                    readonly property real reach: Math.hypot(Math.max(originX, fader.width - originX), Math.max(originY, fader.height - originY))

                    width: round ? reach * 2 * progress : mode === "wipe" ? fader.width * progress : fader.width
                    height: round ? width : fader.height
                    radius: round ? width / 2 : 0
                    x: round ? originX - width / 2 : 0
                    y: round ? originY - height / 2 : 0
                    opacity: mode === "fade" ? progress : 1
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
