pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

// The battery screen: the answer first (how much was used), the curve as a card, apps with their icons
// and share bars, and the reasons as tiles. Everything rises in, one after another.
OverlayWindow {
    id: win

    shown: Power.open
    name: "power"
    scrim: Theme.shade.normal

    readonly property var device: UPower.displayDevice
    // Wh for 100%, to show shares and the curve as percentages.
    readonly property real full: Math.max(1, device?.energyCapacity ?? 1)
    readonly property real topWh: Power.apps.reduce((m, a) => Math.max(m, a.wh ?? 0), 0.001)
    readonly property real usedPct: (Power.why.batt_wh ?? 0) / full * 100
    readonly property int span: Theme.duration.expressiveDefaultSpatial + Theme.power.stagger * 12
    // 0 to 1 over each open; cards and rows rise in from it, one after another.
    property real rise: 0

    function minutes(m: real): string {
        return m >= 60 ? I18n.t("%1 h %2 min").arg(Math.floor(m / 60)).arg(Math.round(m % 60)) : I18n.t("%1 min").arg(Math.round(m));
    }

    function iconFor(app: string): string {
        const entry = DesktopEntries.heuristicLookup(app);
        return entry?.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }

    // How far card number `order` has risen in, 0 to 1.
    function shownAt(order: int): real {
        return Math.min(1, Math.max(0, (rise * span - order * Theme.power.stagger) / Theme.duration.expressiveDefaultSpatial));
    }

    onOpened: {
        sheet.forceActiveFocus();
        rise = 0;
        rising.restart();
    }

    NumberAnimation {
        id: rising

        target: win
        property: "rise"
        to: 1
        duration: win.span
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Power.open = false
    }

    Surface {
        id: sheet

        Keys.onEscapePressed: Power.open = false

        anchors.centerIn: parent
        width: Math.min(Theme.power.width, parent.width - Theme.spacing.extraLarge * 2)
        height: Math.min(body.implicitHeight + Theme.spacing.extraLarge * 2, parent.height - Theme.spacing.extraLarge * 2)
        radius: Theme.rounding.extraLarge
        focus: true
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: body

            anchors {
                fill: parent
                margins: Theme.spacing.extraLarge
            }
            spacing: Theme.spacing.extraLarge

            // The answer first: how much of the battery this range used, and how long is left.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.large

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.extraSmall

                    Text {
                        textFormat: Text.PlainText
                        text: I18n.t("Battery")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: Power.why.batt_wh ? I18n.t("%1% used").arg(win.usedPct.toFixed(win.usedPct < 10 ? 1 : 0)) : I18n.t("No battery use yet")
                        color: Theme.fg
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.huge
                        font.weight: Theme.weight.bold
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: {
                            const parts = [];
                            if (Power.why.batt_min)
                                parts.push(I18n.t("%1 on battery").arg(win.minutes(Power.why.batt_min)));
                            if (UPower.onBattery && (win.device?.timeToEmpty ?? 0) > 0)
                                parts.push(I18n.t("about %1 left").arg(win.minutes(win.device.timeToEmpty / 60)));
                            return parts.join(" · ");
                        }
                        color: Theme.accentText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.larger
                    }
                }

                Segmented {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Theme.power.range
                    implicitHeight: Theme.control.field
                    values: ["unplug", "day", "week", "all"]
                    labels: [I18n.t("Since unplug"), I18n.t("Today"), I18n.t("7 days"), I18n.t("All")]
                    current: Power.range
                    onPicked: value => Power.range = value
                }
            }

            // The level as a card; it draws itself left to right whenever it changes.
            Card {
                order: 0
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.power.curve + Theme.spacing.large * 2

                Canvas {
                    id: curve

                    property real drawn: 0

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.large
                    onDrawnChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const pts = Power.curve;
                        if (pts.length < 2)
                            return;
                        const t0 = pts[0].t, span = Math.max(1, pts[pts.length - 1].t - t0);
                        ctx.save();
                        ctx.beginPath();
                        ctx.rect(0, 0, width * drawn, height);
                        ctx.clip();
                        ctx.beginPath();
                        for (let i = 0; i < pts.length; i++) {
                            const x = (pts[i].t - t0) / span * width;
                            const y = height - Math.min(1, pts[i].wh / win.full) * height;
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = Theme.accentText;
                        ctx.lineWidth = Theme.power.line;
                        ctx.lineJoin = "round";
                        ctx.stroke();
                        ctx.lineTo(width, height);
                        ctx.lineTo(0, height);
                        ctx.closePath();
                        const fade = ctx.createLinearGradient(0, 0, 0, height);
                        fade.addColorStop(0, Qt.alpha(Theme.accentText, Theme.power.fillAlpha));
                        fade.addColorStop(1, Qt.alpha(Theme.accentText, 0));
                        ctx.fillStyle = fade;
                        ctx.fill();
                        ctx.restore();
                    }

                    NumberAnimation {
                        id: draw

                        target: curve
                        property: "drawn"
                        from: 0
                        to: 1
                        duration: Theme.duration.extraLarge
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }

                    Connections {
                        target: Power

                        function onCurveChanged(): void {
                            draw.restart();
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    opacity: Power.curve.length < 2 ? 1 : 0
                    textFormat: Text.PlainText
                    text: Power.loading ? I18n.t("Reading…") : I18n.t("Not enough samples yet")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.extraLarge

                // Apps, by their share of the energy.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.spacing.medium

                    Heading {
                        text: I18n.t("Apps")
                    }

                    Repeater {
                        model: Power.apps.slice(0, Theme.power.apps)

                        Card {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property string icon: win.iconFor(modelData?.app ?? "")

                            order: index + 1
                            Layout.fillWidth: true
                            implicitHeight: Theme.power.appIcon + Theme.spacing.medium * 2

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.spacing.medium
                                spacing: Theme.spacing.medium

                                Item {
                                    implicitWidth: Theme.power.appIcon
                                    implicitHeight: Theme.power.appIcon

                                    Image {
                                        anchors.fill: parent
                                        visible: row.icon !== ""
                                        source: row.icon
                                        sourceSize.width: Theme.power.appIcon * 2
                                        sourceSize.height: Theme.power.appIcon * 2
                                    }

                                    // No desktop entry (a daemon, the kernel): a chip glyph.
                                    MaterialIcon {
                                        anchors.centerIn: parent
                                        visible: row.icon === ""
                                        text: "memory"
                                        color: Theme.dim
                                        size: Theme.icon.normal
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacing.extraSmall

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            textFormat: Text.PlainText
                                            text: row.modelData?.app ?? ""
                                            color: Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize.normal
                                        }

                                        // Plugged-in minutes are estimated from your battery minutes, and say so.
                                        Text {
                                            visible: !!row.modelData?.est && (row.modelData?.wh ?? 0) > 0
                                            textFormat: Text.PlainText
                                            text: I18n.t("estimated")
                                            color: Theme.dim
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize.small
                                        }

                                        Text {
                                            textFormat: Text.PlainText
                                            text: (row.modelData?.wh ?? 0) > 0 ? I18n.t("%1%").arg((row.modelData.wh / win.full * 100).toFixed(1)) : I18n.t("%1 s CPU").arg(row.modelData?.cpu ?? 0)
                                            color: Theme.fg
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: Theme.fontSize.larger
                                            font.weight: Theme.weight.bold
                                            font.features: ({
                                                    tnum: 1
                                                })
                                        }
                                    }

                                    // A thin rounded share bar; it grows in with its card, scaled, never resized.
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: Theme.power.bar
                                        radius: height / 2
                                        color: Theme.bgAlt

                                        Rectangle {
                                            width: parent.width
                                            height: parent.height
                                            radius: height / 2
                                            color: Theme.accentText
                                            transform: Scale {
                                                xScale: (row.modelData?.wh ?? 0) / win.topWh * row.shown

                                                Behavior on xScale {
                                                    enabled: win.visible && win.rise >= 1

                                                    NumberAnimation {
                                                        duration: Theme.duration.expressiveDefaultSpatial
                                                        easing.type: Easing.BezierSpline
                                                        easing.bezierCurve: Theme.curve.emphasizedDecel
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: Power.apps.length === 0
                        textFormat: Text.PlainText
                        text: Power.loading ? I18n.t("Reading…") : I18n.t("Nothing logged in this range")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }
                }

                // Why, as tiles: a glyph and one big value each.
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.spacing.medium

                    Heading {
                        text: I18n.t("Why")
                    }

                    // Fixed-width tiles: a filling grid would take the apps' room (Layout.fillWidth is contagious).
                    GridLayout {
                        columns: Theme.power.tiles
                        columnSpacing: Theme.spacing.medium
                        rowSpacing: Theme.spacing.medium

                        Tile {
                            order: 1
                            icon: "light_mode"
                            label: I18n.t("Brightness")
                            value: Power.why.bright != null ? I18n.t("%1%").arg(Power.why.bright) : "—"
                        }
                        Tile {
                            order: 2
                            icon: "bedtime"
                            label: I18n.t("Asleep")
                            value: Power.sleep.n ? I18n.t("%1 Wh").arg(Power.sleep.wh) : "—"
                        }
                        Tile {
                            order: 3
                            icon: "bolt"
                            label: I18n.t("Average draw")
                            value: Power.why.batt_w ? I18n.t("%1 W").arg(Power.why.batt_w) : "—"
                        }
                        Tile {
                            order: 4
                            icon: "wifi"
                            label: I18n.t("Wi-Fi on")
                            value: Power.why.wifi_min ? win.minutes(Power.why.wifi_min) : "—"
                        }
                        Tile {
                            order: 5
                            icon: "bluetooth"
                            label: I18n.t("Bluetooth on")
                            value: Power.why.bt_min ? win.minutes(Power.why.bt_min) : "—"
                        }
                        Tile {
                            order: 6
                            icon: "memory"
                            label: I18n.t("CPU")
                            value: Power.why.cpu != null ? I18n.t("%1%").arg(Power.why.cpu) : "—"
                        }
                        Tile {
                            order: 7
                            Layout.columnSpan: Theme.power.tiles
                            icon: "tune"
                            label: I18n.t("Power profile")
                            value: Power.profiles.map(p => I18n.t(p.profile)).join(" · ") || "—"
                        }
                    }
                }
            }
        }
    }

    component Heading: Text {
        textFormat: Text.PlainText
        color: Theme.fg
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.fontSize.large
        font.weight: Theme.weight.bold
    }

    // A rounded card that rises in on open, after the cards before it.
    component Card: Rectangle {
        id: card

        property int order: 0
        readonly property real shown: win.shownAt(order)

        radius: Theme.rounding.large
        color: Theme.bgTray
        opacity: shown
        transform: Translate {
            y: (1 - card.shown) * Theme.power.rise
        }
    }

    component Tile: Card {
        id: tile

        property string icon
        property string label
        property string value

        implicitWidth: Layout.columnSpan > 1 ? Theme.power.tile * Theme.power.tiles + Theme.spacing.medium * (Theme.power.tiles - 1) : Theme.power.tile
        implicitHeight: Theme.power.tile

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacing.medium
            spacing: Theme.spacing.extraSmall

            MaterialIcon {
                text: tile.icon
                color: Theme.accentText
                size: Theme.icon.normal
                fill: 1
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: tile.value
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.larger
                font.weight: Theme.weight.bold
                font.features: ({
                        tnum: 1
                    })
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: tile.label
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }
    }
}
