pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import ".."

// Plugging in sends a ring of sparkling light up the screen from the bottom
// edge, where a phone's port would be, with the charge underneath it. It is
// drawn over everything and takes no input.
Scope {
    id: root

    property bool playing: false
    property real progress: 0

    function play(): void {
        seed();
        playing = true;
        run.restart();
        Quickshell.execDetached(["canberra-gtk-play", "-i", "power-plug"]);
    }

    // Sparkles, fixed for one ripple: an angle across the upper half, a depth
    // inside the ring, a size and a twinkle phase.
    property var sparks: []

    function seed(): void {
        const s = [];
        for (let i = 0; i < 280; i++)
            s.push({
                a: Math.PI + Math.random() * Math.PI,
                d: Math.random(),
                size: 0.6 + Math.random() * 1.8,
                phase: Math.random() * Math.PI * 2
            });
        sparks = s;
    }

    NumberAnimation {
        id: run
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Theme.duration.extraLarge * 1.6
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.curve.standardDecel
        onFinished: root.playing = false
    }

    PanelWindow {
        id: win

        visible: root.playing
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.namespace: "charge-ripple"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        // Nothing here takes a click.
        mask: Region {}

        Canvas {
            id: canvas

            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded

            Connections {
                target: root

                function onProgressChanged(): void {
                    canvas.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!root.playing)
                    return;
                const p = root.progress;
                const ox = width / 2, oy = height + Theme.spacing.large;
                const reach = Math.hypot(width / 2, height) * 1.05;
                const r = reach * p;
                const band = reach * 0.22;
                // Full strength while it spreads, gone by the end.
                const fade = p < 0.55 ? 1 : 1 - (p - 0.55) / 0.45;
                const c = Theme.accentText;

                // The glow: a band that brightens toward the leading edge.
                const inner = Math.max(0, r - band);
                const g = ctx.createRadialGradient(ox, oy, inner, ox, oy, r + 1);
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0));
                g.addColorStop(0.75, Qt.rgba(c.r, c.g, c.b, 0.16 * fade));
                g.addColorStop(0.97, Qt.rgba(1, 1, 1, 0.22 * fade));
                g.addColorStop(1, Qt.rgba(1, 1, 1, 0));
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.arc(ox, oy, r + 1, 0, Math.PI * 2);
                ctx.fill();

                // The sparkles, riding inside the band and twinkling.
                for (const s of root.sparks) {
                    const sr = r - s.d * band;
                    if (sr <= 0)
                        continue;
                    const tw = 0.5 + 0.5 * Math.sin(s.phase + p * 40);
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.85 * fade * tw * (1 - s.d * 0.7));
                    ctx.beginPath();
                    ctx.arc(ox + sr * Math.cos(s.a), oy + sr * Math.sin(s.a), s.size, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }

        // The charge, low and centred, like the phone's line under its clock.
        Text {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: Theme.padding.extraLarge * 2
            }
            opacity: root.progress < 0.15 ? root.progress / 0.15 : root.progress > 0.6 ? 1 - (root.progress - 0.6) / 0.4 : 1
            text: Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + " %  ·  Charging"
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.medium
        }
    }

    IpcHandler {
        target: "charge"

        // For seeing it without unplugging anything.
        function play(): void {
            root.play();
        }
    }
}
