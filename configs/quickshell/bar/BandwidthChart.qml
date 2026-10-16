import QtQuick
import QtQuick.Layouts
import ".."

// The last minute of traffic on one scale: download as a filled line, upload as a line.
ColumnLayout {
    id: root

    // Idle chatter must not stretch the scale.
    readonly property real ceiling: Net.downHist.concat(Net.upHist).reduce((m, v) => Math.max(m, v), Theme.bar.busyAt)

    function peak(data: var): real {
        return data.reduce((m, v) => Math.max(m, v), 0);
    }

    spacing: Theme.spacing.small

    Connections {
        function onDownHistChanged(): void {
            canvas.requestPaint();
        }

        target: Net
    }

    Text {
        text: I18n.t("Network, last %1 s").arg(Theme.bar.chartSamples)
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
    }

    Canvas {
        id: canvas

        // Newest at the right edge; the line runs from the bottom up.
        function trace(ctx: var, data: var): void {
            const step = width / (Theme.bar.chartSamples - 1);
            const room = height - Theme.bar.chartLine;
            ctx.beginPath();
            for (let i = 0; i < data.length; i++) {
                const x = width - (data.length - 1 - i) * step;
                const y = height - Theme.bar.chartLine / 2 - data[i] / root.ceiling * room;
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = Theme.bar.chartLine;
            ctx.lineJoin = "round";
            const down = Net.downHist;
            if (down.length > 1) {
                trace(ctx, down);
                ctx.strokeStyle = Theme.accentText;
                ctx.stroke();
                ctx.lineTo(width, height);
                ctx.lineTo(width - (down.length - 1) * width / (Theme.bar.chartSamples - 1), height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(Theme.accentText, Theme.bar.chartFill);
                ctx.fill();
            }
            if (Net.upHist.length > 1) {
                trace(ctx, Net.upHist);
                ctx.strokeStyle = Theme.accent2;
                ctx.stroke();
            }
        }

        Layout.preferredWidth: Theme.bar.chartWidth
        Layout.preferredHeight: Theme.bar.chartHeight
    }

    RowLayout {
        spacing: Theme.spacing.large

        Repeater {
            model: [
                {
                    glyph: "south",
                    tone: Theme.accentText,
                    now: Net.downRate,
                    peak: root.peak(Net.downHist)
                },
                {
                    glyph: "north",
                    tone: Theme.accent2,
                    now: Net.upRate,
                    peak: root.peak(Net.upHist)
                }
            ]

            RowLayout {
                id: legend

                required property var modelData

                spacing: Theme.spacing.extraSmall

                MaterialIcon {
                    text: legend.modelData.glyph
                    color: legend.modelData.tone
                    size: Theme.icon.small
                }

                Text {
                    text: I18n.t("%1 now · %2 peak").arg(Net.human(legend.modelData.now)).arg(Net.human(legend.modelData.peak))
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                }
            }
        }
    }
}
