pragma ComponentBehavior: Bound

import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

// The battery screen, laid out like the cheat sheet: a curve of the level, then what used it and why.
OverlayWindow {
    id: win

    shown: Power.open
    name: "power"
    scrim: Theme.shade.normal

    // Wh for 100%, to show shares and the curve as percentages.
    readonly property real full: Math.max(1, UPower.displayDevice?.energyCapacity ?? 1)
    readonly property real topWh: Power.apps.reduce((m, a) => Math.max(m, a.wh ?? 0), 0.001)

    function minutes(m: real): string {
        return m >= 60 ? I18n.t("%1 h %2 min").arg(Math.floor(m / 60)).arg(Math.round(m % 60)) : I18n.t("%1 min").arg(Math.round(m));
    }

    onOpened: sheet.forceActiveFocus()

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

        // Clicks on the sheet stay on the sheet.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: body

            anchors {
                fill: parent
                margins: Theme.spacing.extraLarge
            }
            spacing: Theme.spacing.large

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing.large

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: I18n.t("Battery")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.weight: Theme.weight.bold
                }

                Segmented {
                    Layout.preferredWidth: Theme.power.range
                    implicitHeight: Theme.control.field
                    values: ["unplug", "day", "week", "all"]
                    labels: [I18n.t("Since unplug"), I18n.t("Today"), I18n.t("7 days"), I18n.t("All")]
                    current: Power.range
                    onPicked: value => Power.range = value
                }
            }

            // The level over the range; flat stretches are plugged in or asleep.
            Canvas {
                id: curve

                Layout.fillWidth: true
                Layout.preferredHeight: Theme.power.curve
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const pts = Power.curve;
                    if (pts.length < 2)
                        return;
                    const t0 = pts[0].t, span = Math.max(1, pts[pts.length - 1].t - t0);
                    ctx.strokeStyle = Theme.accentText;
                    ctx.lineWidth = Theme.power.line;
                    ctx.beginPath();
                    pts.forEach((p, i) => {
                        const x = (p.t - t0) / span * width;
                        const y = height - Math.min(1, p.wh / win.full) * height;
                        if (i === 0)
                            ctx.moveTo(x, y);
                        else
                            ctx.lineTo(x, y);
                    });
                    ctx.stroke();
                }

                Connections {
                    target: Power

                    function onCurveChanged(): void {
                        curve.requestPaint();
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Power.curve.length < 2
                    textFormat: Text.PlainText
                    text: Power.loading ? I18n.t("Reading…") : I18n.t("Not enough samples yet")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spacing.extraLarge

                // What used it: each app's share of the energy, by its CPU time.
                ColumnLayout {
                    Layout.preferredWidth: (body.width - Theme.spacing.extraLarge) * 0.6
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.spacing.small

                    Heading {
                        text: I18n.t("Apps")
                    }

                    Repeater {
                        model: Power.apps

                        Item {
                            id: row

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: Theme.power.row

                            // The bar behind each row is its share, scaled, never resized.
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.rounding.extraSmall
                                color: Theme.bgTray
                                transformOrigin: Item.Left
                                transform: Scale {
                                    xScale: (row.modelData?.wh ?? 0) / win.topWh
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacing.medium
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.6
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                                text: row.modelData.app
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.normal
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacing.medium
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.PlainText
                                // Plugged-in minutes are estimated from the battery's own fit, and say so.
                                text: (row.modelData.wh > 0 ? I18n.t("%1% · %2 Wh").arg((row.modelData.wh / win.full * 100).toFixed(1)).arg(row.modelData.wh.toFixed(2)) : I18n.t("%1 s CPU").arg(row.modelData.cpu)) + (row.modelData.est ? " ~" : "")
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.smaller
                                font.features: ({
                                        tnum: 1
                                    })
                            }
                        }
                    }

                    Text {
                        visible: Power.apps.length === 0
                        textFormat: Text.PlainText
                        text: I18n.t("Nothing logged in this range")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: I18n.t("~ estimated while plugged in, from your battery minutes")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }

                // Why: the conditions while it ran.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Theme.spacing.small

                    Heading {
                        text: I18n.t("Why")
                    }

                    Fact {
                        label: I18n.t("On battery")
                        value: win.minutes(Power.why.batt_min ?? 0) + (Power.why.batt_w ? I18n.t(" · %1 W avg").arg(Power.why.batt_w) : "")
                    }
                    Fact {
                        label: I18n.t("Used on battery")
                        value: I18n.t("%1 Wh").arg(Power.why.batt_wh ?? 0)
                    }
                    Fact {
                        label: I18n.t("Asleep")
                        value: I18n.t("%1 Wh in %2").arg(Power.sleep.wh ?? 0).arg(win.minutes((Power.sleep.secs ?? 0) / 60))
                    }
                    Fact {
                        label: I18n.t("Brightness")
                        value: Power.why.bright != null ? I18n.t("%1% avg").arg(Power.why.bright) : "—"
                    }
                    Fact {
                        label: I18n.t("CPU")
                        value: Power.why.cpu != null ? I18n.t("%1% avg").arg(Power.why.cpu) : "—"
                    }
                    Fact {
                        label: I18n.t("Wi-Fi on")
                        value: win.minutes(Power.why.wifi_min ?? 0)
                    }
                    Fact {
                        label: I18n.t("Bluetooth on")
                        value: win.minutes(Power.why.bt_min ?? 0)
                    }
                    Fact {
                        label: I18n.t("Power profile")
                        value: Power.profiles.map(p => p.profile + " " + win.minutes(p.mins)).join(", ") || "—"
                    }
                }
            }
        }
    }

    component Heading: Text {
        textFormat: Text.PlainText
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
        font.weight: Theme.weight.medium
        font.letterSpacing: Theme.tracking.wider
    }

    component Fact: RowLayout {
        property string label
        property string value

        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: parent.label
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
        }

        Text {
            textFormat: Text.PlainText
            text: parent.value
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.normal
            font.features: ({
                    tnum: 1
                })
        }
    }
}
