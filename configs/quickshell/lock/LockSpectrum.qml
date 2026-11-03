pragma ComponentBehavior: Bound

import QtQuick
import ".."

// The music behind the clock: Cava's bands mirrored out from the middle, lows at the centre.
Item {
    id: spectrum

    readonly property int count: Cava.bars * Theme.lock.spectrumSpread * 2
    readonly property real half: count / 2
    readonly property real slot: width / count

    // Between two of Cava's bands, so the bars outnumber them without steps.
    function level(d: real): real {
        const at = d / Theme.lock.spectrumSpread, i = Math.floor(at), f = at - i;
        const a = Cava.levels[i] ?? 0, b = Cava.levels[i + 1] ?? a;
        return a + (b - a) * f;
    }

    // Tall in the middle and low at the ends, a hill like a phone's lock screen.
    function taper(t: real): real {
        return 1 - Theme.lock.spectrumTaper * (1 - Math.cos(t * Math.PI / 2));
    }

    function tone(t: real): color {
        const a = Theme.accentText, b = Theme.accent2;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    visible: opacity > 0
    opacity: Cava.running ? Theme.lock.spectrumOpacity : 0
    layer.enabled: opacity < Theme.lock.spectrumOpacity

    layer.effect: MotionBlur {
        settled: spectrum.opacity / Theme.lock.spectrumOpacity
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }

    Repeater {
        model: spectrum.count

        Rectangle {
            id: bar

            required property int index
            // How far from the middle, 0 to 1.
            readonly property real out: Math.abs(index - (spectrum.count - 1) / 2) / spectrum.half
            readonly property real level: spectrum.level(bar.out * (Cava.bars - 1) * Theme.lock.spectrumSpread) * spectrum.taper(bar.out)

            x: index * spectrum.slot + (spectrum.slot - width) / 2
            y: 0
            width: spectrum.slot * (1 - Theme.lock.spectrumGap)
            height: spectrum.height
            radius: Math.max(1, width / 2)
            color: spectrum.tone(bar.out)

            // Drawn once at full height and scaled, so a frame never re-lays it out.
            transform: Scale {
                origin.y: bar.height
                yScale: Math.max(Theme.lock.spectrumFloor, bar.level)

                Behavior on yScale {
                    NumberAnimation {
                        duration: Theme.lock.spectrumEase
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
