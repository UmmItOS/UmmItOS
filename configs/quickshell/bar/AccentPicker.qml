pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

BarButton {
    id: root

    // Brand purple, then Color Hunt fills dark enough for white text.
    readonly property var presets: ["#5003c0", "#ab03a9", "#d45060", "#972828", "#e45742", "#c49a45", "#2a835f", "#12544f", "#76c0ec", "#22396f", "#2f39a9", "#800020"]

    property bool popupOpen: false

    // "#rrggbb", "#aarrggbb", or "rgba(r, g, b[, a])" with a in 0-1.
    function parse(input: string): var {
        const s = input.trim();
        if (/^#([0-9a-f]{6}|[0-9a-f]{8})$/i.test(s))
            return s;
        const m = s.match(/^rgba?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*(\d*\.?\d+))?\s*\)$/i);
        if (!m || [m[1], m[2], m[3]].some(v => Number(v) > 255) || Number(m[4] ?? 1) > 1)
            return null;
        return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : Number(m[4]));
    }

    readonly property var used: AccentTime.ranked.slice(0, Theme.bar.accentYours)
    // Every cell the same width, so the used row lines up with the presets under it.
    property real cell: 0

    component Heading: Text {
        color: Theme.fg
        font {
            family: Theme.font
            pixelSize: Theme.fontSize.smaller
            weight: Theme.weight.bold
        }
    }

    component Swatch: Rectangle {
        id: swatch

        property string colour
        // A colour in both rows is ticked once, in the used row.
        property bool tick: Qt.colorEqual(Theme.accent, colour)

        implicitWidth: root.cell
        implicitHeight: Theme.control.pill
        radius: Theme.rounding.full
        color: hover.hovered ? Qt.lighter(colour, Theme.bar.swatchHover) : colour
        scale: tap.pressed ? Theme.pressScale : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveFastEffects
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.duration.expressiveFastSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curve.expressiveFastSpatial
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            visible: swatch.tick
            text: "check"
            color: Theme.accentOn
            size: Theme.icon.small
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap
            onTapped: Theme.setAccent(swatch.colour)
        }
    }

    icon: "palette"
    label: "Accent colour"
    onClicked: popupOpen = !popupOpen

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: I18n.t("Accent")
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false

        Heading {
            visible: root.used.length > 0
            text: I18n.t("Most used")
        }

        // Longest first; a colour moving up slides into place instead of the row being rebuilt each minute.
        ListView {
            id: yours

            Layout.fillWidth: true
            implicitHeight: Theme.control.pill + Theme.spacing.extraSmall + Theme.fontSize.small * 2
            visible: count > 0
            orientation: ListView.Horizontal
            interactive: false
            spacing: Theme.spacing.medium
            model: ScriptModel {
                values: root.used
            }

            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }
            move: Transition {
                NumberAnimation {
                    property: "x"
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }
            }
            displaced: Transition {
                NumberAnimation {
                    property: "x"
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }
            }

            delegate: Column {
                id: entry

                required property string modelData
                required property int index

                spacing: Theme.spacing.extraSmall

                Swatch {
                    colour: entry.modelData
                }

                // The longest one reads first: bright and bold, the rest dim.
                Text {
                    width: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: AccentTime.spoken(AccentTime.seconds[entry.modelData] ?? 0)
                    color: entry.index === 0 ? Theme.fg : Theme.dim
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.small
                        weight: entry.index === 0 ? Theme.weight.bold : Theme.weight.regular
                        features: ({
                                tnum: 1
                            })
                    }
                }
            }
        }

        Heading {
            visible: root.used.length > 0
            text: I18n.t("Presets")
        }

        // Always shown, so it measures the cells for both rows.
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium
            onWidthChanged: root.cell = (width - (Theme.bar.accentColumns - 1) * spacing) / Theme.bar.accentColumns

            Repeater {
                model: root.presets

                Swatch {
                    required property string modelData

                    colour: modelData
                    tick: Qt.colorEqual(Theme.accent, modelData) && !root.used.includes(Theme.accent.toString())
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.control.field
            radius: Theme.rounding.full
            color: Theme.bgAlt

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.medium
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

                    // Typing breaks the text binding; follow every accent change.
                    Connections {
                        target: Theme
                        function onAccentChanged(): void {
                            field.text = Theme.accent.toString();
                            field.bad = false;
                        }
                    }
                    function commit(): void {
                        const c = root.parse(text);
                        bad = c === null;
                        if (c !== null)
                            Theme.setAccent(c);
                    }

                    Keys.onReturnPressed: commit()
                    Keys.onEnterPressed: commit()
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
            text: I18n.t("#hex or rgba(r, g, b, a), then Enter")
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
            }
        }
    }
}
