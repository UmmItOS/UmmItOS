pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// The accent colour, chosen in place. Twelve swatches cover the common wish
// without a colour wheel; the field takes anything else, as #hex or rgba().
BarButton {
    id: root

    // Brand purple first, then eleven fills taken from Color Hunt's popular
    // palettes (colorhunt.co), round the wheel. Each is dark enough to carry
    // white text, as the purple does.
    readonly property var presets: ["#5003c0", "#ab03a9", "#d45060", "#972828", "#e45742", "#c49a45", "#2a835f", "#12544f", "#76c0ec", "#22396f", "#2f39a9", "#800020"]

    property bool popupOpen: false

    // "#rrggbb", "#aarrggbb", or "rgba(r, g, b[, a])" with a in 0-1.
    function parse(input: string): var {
        const s = input.trim();
        if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(s))
            return s;
        const m = s.match(/^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([01]?(?:\.\d+)?))?\s*\)$/i);
        if (!m || [m[1], m[2], m[3]].some(v => Number(v) > 255))
            return null;
        return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : Number(m[4]));
    }

    icon: "palette"
    onClicked: popupOpen = !popupOpen

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: "Accent"
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: Theme.spacing.medium
            columnSpacing: Theme.spacing.medium

            Repeater {
                model: root.presets

                Rectangle {
                    id: swatch

                    required property string modelData
                    readonly property bool chosen: Qt.colorEqual(Theme.accent, modelData)

                    Layout.fillWidth: true
                    implicitHeight: Theme.control.pill
                    radius: Theme.rounding.full
                    color: modelData
                    scale: tap.pressed ? Theme.pressScale : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.expressiveFastSpatial
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: swatch.chosen
                        text: "check"
                        color: Theme.fg
                        size: Theme.icon.small
                    }

                    TapHandler {
                        id: tap
                        onTapped: Theme.setAccent(swatch.modelData)
                    }
                }
            }
        }

        // Anything the swatches do not cover. Enter applies; a value that does
        // not parse turns the field red instead of silently doing nothing.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.control.field
            radius: Theme.rounding.full
            color: Theme.bgAlt

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.padding.large
                    rightMargin: Theme.padding.medium
                }
                spacing: Theme.spacing.small

                TextInput {
                    id: field

                    property bool bad: false

                    Layout.fillWidth: true
                    text: Theme.accent.toString()
                    color: bad ? Theme.urgent : Theme.fg
                    selectByMouse: true
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                    }

                    onTextEdited: bad = false

                    // Typing breaks the text binding, and a swatch picked after
                    // a bad entry left the field red; follow every change.
                    Connections {
                        target: Theme
                        function onAccentChanged(): void {
                            field.text = Theme.accent.toString();
                            field.bad = false;
                        }
                    }
                    Keys.onReturnPressed: {
                        const c = root.parse(text);
                        bad = c === null;
                        if (c !== null)
                            Theme.setAccent(c);
                    }
                }

                // Live preview of what is in effect.
                Rectangle {
                    implicitWidth: Theme.icon.small
                    implicitHeight: Theme.icon.small
                    radius: width / 2
                    color: Theme.accent
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "#hex or rgba(r, g, b, a), then Enter"
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
            }
        }
    }
}
