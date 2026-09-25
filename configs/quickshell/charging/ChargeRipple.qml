pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick
import ".."

Scope {
    id: root

    property bool playing: false
    property real progress: 0

    function play(): void {
        seed();
        playing = true;
        run.restart();
        // Original chime, synthesised for this (plug.ogg).
        Quickshell.execDetached(["pw-play", Qt.resolvedUrl("plug.ogg").toString().replace("file://", "")]);
    }

    // Grains as (distance 0-1, angle); each lights as the ring passes.
    property var sparks: []
    property var wobble: []

    function seed(): void {
        const s = [];
        for (let i = 0; i < 700; i++)
            s.push({
                a: Math.PI + Math.random() * Math.PI,
                r: Math.sqrt(Math.random()),
                size: 1 + Math.random() * 2,
                phase: Math.random() * Math.PI * 2,
                speed: 25 + Math.random() * 35
            });
        sparks = s;
        wobble = [0, 1, 2].map(() => ({
                    k: 3 + Math.floor(Math.random() * 6),
                    phase: Math.random() * Math.PI * 2
                }));
    }

    // 0.4-1.0 around the arc: how bright the edge is at angle `a`.
    function strength(a: real): real {
        let v = 0;
        for (const w of wobble)
            v += Math.sin(a * w.k + w.phase);
        return 0.7 + 0.3 * v / 3;
    }

    NumberAnimation {
        id: run
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Theme.duration.extraLarge * 2
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
                // Runs ahead so the ring leaves while the glitter settles.
                const r = reach * Math.min(1, p * 1.25);
                const band = reach * 0.2;
                const fade = p < 0.6 ? 1 : 1 - (p - 0.6) / 0.4;
                const c = Theme.accentText;

                // The glow behind the edge, and a fainter echo trailing it.
                const rings = [[r, 1], [r * 0.72, 0.35]];
                for (const [rr, k] of rings) {
                    if (rr <= 1)
                        continue;
                    const g = ctx.createRadialGradient(ox, oy, Math.max(0, rr - band), ox, oy, rr + 2);
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0));
                    g.addColorStop(0.7, Qt.rgba(c.r, c.g, c.b, 0.14 * k * fade));
                    g.addColorStop(0.96, Qt.rgba(c.r, c.g, c.b, 0.3 * k * fade));
                    g.addColorStop(1, Qt.rgba(1, 1, 1, 0));
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.arc(ox, oy, rr + 2, 0, Math.PI * 2);
                    ctx.fill();
                }

                const steps = 90;
                ctx.lineWidth = 2;
                for (let i = 0; i < steps; i++) {
                    const a0 = Math.PI + Math.PI * i / steps;
                    const a1 = Math.PI + Math.PI * (i + 1) / steps;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55 * fade * root.strength(a0) * root.strength(a0 + p * 3));
                    ctx.beginPath();
                    ctx.arc(ox, oy, r, a0, a1);
                    ctx.stroke();
                }

                for (const s of root.sparks) {
                    const sr = s.r * reach;
                    const since = (r - sr) / reach;
                    if (since < 0)
                        continue;
                    const life = Math.max(0, 1 - since / 0.5);
                    if (life <= 0)
                        continue;
                    const tw = 0.55 + 0.45 * Math.sin(s.phase + p * s.speed);
                    ctx.fillStyle = Qt.rgba(1, 1, 1, Math.min(1, 1.2 * life) * tw * fade);
                    ctx.beginPath();
                    ctx.arc(ox + sr * Math.cos(s.a), oy + sr * Math.sin(s.a), s.size * (0.6 + 0.4 * life), 0, Math.PI * 2);
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
