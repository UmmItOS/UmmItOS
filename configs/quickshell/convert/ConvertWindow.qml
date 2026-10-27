pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."

// GTA V's weapon wheel with formats for weapons: drop pictures on it, point at a slot, click. Then the mission banner.
OverlayWindow {
    id: win

    readonly property real step: 360 / Convert.formats.length
    readonly property real centre: Theme.gta.outer
    readonly property real middle: (Theme.gta.outer + Theme.gta.inner) / 2
    readonly property string current: Convert.files[Convert.index] ?? ""
    // A drag hovering the wheel.
    property bool dragging: false
    // Kept through the banner's fade-out, after the singleton has cleared it.
    property string outcome: "passed"

    // The slot under a point of the wheel, clockwise from the top, or -1 in the hub.
    function slotAt(x: real, y: real): int {
        const dx = x - centre, dy = y - centre;
        if (Math.hypot(dx, dy) < Theme.gta.inner || Math.hypot(dx, dy) > Theme.gta.outer)
            return -1;
        const angle = (Math.atan2(dx, -dy) * 180 / Math.PI + 360 + step / 2) % 360;
        return Math.floor(angle / step);
    }

    // A local path as a URL; a path can hold # or ?, which would end it early.
    function source(item: string): string {
        if (item === "" || /^https?:\/\//i.test(item))
            return item;
        return "file://" + item.split("/").map(encodeURIComponent).join("/");
    }

    // The gap between slots is the same width at both edges of the ring, so it is a different angle at each.
    function gapAngle(radius: real): real {
        return Math.asin(Theme.gta.gap / 2 / radius) * 180 / Math.PI;
    }

    onOpened: dragging = false

    shown: Convert.shown
    name: "convert"
    // Not Exclusive: Hyprland lets no other surface start a drag while a layer holds the keyboard.
    focusMode: Convert.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // Only the wheel takes the pointer, so a picture can still be dragged from the windows around it.
    mask: Convert.open ? wheelRegion : noRegion

    Connections {
        function onResultChanged(): void {
            if (Convert.result !== "")
                win.outcome = Convert.result;
        }

        target: Convert
    }

    Region {
        id: wheelRegion

        item: wheel
        shape: RegionShape.Ellipse
    }

    Region {
        id: noRegion
    }

    Item {
        anchors.fill: parent
        focus: true


        Keys.onEscapePressed: Convert.toggle()
        Keys.onTabPressed: Convert.step(1)
        Keys.onBacktabPressed: Convert.step(-1)
        Keys.onRightPressed: Convert.step(1)
        Keys.onDownPressed: Convert.step(1)
        Keys.onLeftPressed: Convert.step(-1)
        Keys.onUpPressed: Convert.step(-1)
        Keys.onReturnPressed: Convert.convert()
        Keys.onEnterPressed: Convert.convert()
        Keys.onSpacePressed: Convert.convert()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageUp)
                Convert.flip(-1);
            else if (event.key === Qt.Key_PageDown)
                Convert.flip(1);
        }

        // The wheel.
        Item {
            id: wheel

            anchors.centerIn: parent
            width: Theme.gta.outer * 2
            height: width
            opacity: Convert.open ? 1 : 0
            scale: !Convert.open ? Theme.gta.openScale : win.dragging ? Theme.gta.dropScale : 1
            layer.enabled: opacity < 1

            layer.effect: MotionBlur {
                settled: wheel.opacity
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Convert.open ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            HoverHandler {
                id: hover

                onPointChanged: {
                    const slot = win.slotAt(point.position.x, point.position.y);
                    if (slot >= 0)
                        Convert.choice = Convert.busy ? Convert.choice : slot;
                }

                cursorShape: Convert.files.length > 0 && win.slotAt(point.position.x, point.position.y) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                onTapped: point => {
                    const slot = win.slotAt(point.position.x, point.position.y);
                    if (slot < 0)
                        return;
                    Convert.choice = slot;
                    Convert.convert();
                }
            }

            WheelHandler {
                onWheel: event => Convert.step(event.angleDelta.y > 0 ? -1 : 1)
            }

            DropArea {
                anchors.fill: parent

                onEntered: win.dragging = true
                onExited: win.dragging = false
                onDropped: drop => {
                    win.dragging = false;
                    Convert.take(drop.urls, drop.hasText ? drop.text : "");
                    drop.acceptProposedAction();
                }
            }

            Repeater {
                model: Convert.formats

                Item {
                    id: slot

                    required property int index
                    required property var modelData
                    readonly property bool lit: slot.index === Convert.choice
                    // The slot's middle, in degrees clockwise from the top.
                    readonly property real angle: slot.index * win.step
                    readonly property real outerGap: win.gapAngle(Theme.gta.outer)
                    readonly property real innerGap: win.gapAngle(Theme.gta.inner)

                    anchors.fill: parent

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            id: wedge

                            strokeWidth: -1
                            fillColor: slot.lit ? Theme.gta.slotLit : Theme.gta.slot

                            Behavior on fillColor {
                                FastColor {}
                            }

                            // Qt's angles run clockwise from three o'clock.
                            PathAngleArc {
                                centerX: win.centre
                                centerY: win.centre
                                radiusX: Theme.gta.outer
                                radiusY: Theme.gta.outer
                                startAngle: slot.angle - 90 - win.step / 2 + slot.outerGap
                                sweepAngle: win.step - slot.outerGap * 2
                            }

                            PathAngleArc {
                                centerX: win.centre
                                centerY: win.centre
                                radiusX: Theme.gta.inner
                                radiusY: Theme.gta.inner
                                startAngle: slot.angle - 90 + win.step / 2 - slot.innerGap
                                sweepAngle: -(win.step - slot.innerGap * 2)
                                moveToStart: false
                            }
                        }
                    }

                    // The weapon: the format's glyph, its name, and a word where the ammo count would be.
                    Column {
                        x: win.centre + win.middle * Math.sin(slot.angle * Math.PI / 180) - width / 2
                        y: win.centre - win.middle * Math.cos(slot.angle * Math.PI / 180) - height / 2
                        spacing: 0
                        scale: slot.lit ? Theme.gta.lit : 1

                        Behavior on scale {
                            PressAnim {}
                        }

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: slot.modelData.icon
                            size: Theme.gta.icon
                            fill: slot.lit ? 1 : 0
                            color: Theme.gta.text
                            style: Text.Outline
                            styleColor: Theme.gta.outline
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            textFormat: Text.PlainText
                            text: slot.modelData.ext.toUpperCase()
                            color: Theme.gta.text
                            style: Text.Outline
                            styleColor: Theme.gta.outline
                            font.family: Theme.font
                            font.pixelSize: Theme.gta.name
                            font.weight: Theme.weight.bold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            textFormat: Text.PlainText
                            text: I18n.t(slot.modelData.hint)
                            color: Theme.gta.soft
                            style: Text.Outline
                            styleColor: Theme.gta.outline
                            font.family: Theme.font
                            font.pixelSize: Theme.gta.hint
                        }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: (Theme.gta.inner - Theme.gta.gap) * 2
                height: width
                radius: width / 2
                color: Theme.gta.hub
            }

            // The hub: what is loaded and what the picked slot does, or where to drop.
            Column {
                anchors.centerIn: parent
                width: Theme.gta.inner * 2 - Theme.spacing.extraLarge * 2
                spacing: Theme.spacing.small

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Convert.files.length === 0
                    text: win.dragging ? "file_download_done" : "file_download"
                    size: Theme.gta.icon
                    color: Theme.gta.text
                    style: Text.Outline
                    styleColor: Theme.gta.outline
                }

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Convert.files.length > 0 && !Convert.busy
                    width: Theme.gta.thumb
                    height: Theme.gta.thumb
                    source: win.source(win.current)
                    sourceSize.width: Theme.gta.thumb * 2
                    sourceSize.height: Theme.gta.thumb * 2
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        FastFade {}
                    }
                }

                Spinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Convert.busy
                    size: Theme.gta.icon
                    color: Theme.gta.text
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: Convert.busy ? I18n.t("Converting %1 of %2").arg(Math.min(Convert.done + 1, Convert.files.length)).arg(Convert.files.length) : Convert.files.length > 0 ? Convert.name(win.current) : win.dragging ? I18n.t("Let go to load") : I18n.t("Drop pictures here")
                    elide: Text.ElideMiddle
                    color: Theme.gta.text
                    style: Text.Outline
                    styleColor: Theme.gta.outline
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    font.weight: Theme.weight.bold
                }

                // GTA's ‹ 4 / 5 ›, flipping through the dropped pictures.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Convert.files.length > 1 && !Convert.busy
                    spacing: Theme.spacing.small

                    Repeater {
                        model: [-1, 0, 1]

                        Item {
                            id: flipper

                            required property int modelData

                            implicitWidth: flipper.modelData === 0 ? count.implicitWidth : arrow.implicitWidth
                            implicitHeight: arrow.implicitHeight

                            MaterialIcon {
                                id: arrow

                                anchors.centerIn: parent
                                visible: flipper.modelData !== 0
                                text: flipper.modelData < 0 ? "chevron_left" : "chevron_right"
                                size: Theme.icon.normal
                                color: flipTap.hovered ? Theme.gta.gold : Theme.gta.text
                                style: Text.Outline
                                styleColor: Theme.gta.outline
                                scale: flipTap.pressed ? Theme.pressScale : 1

                                Behavior on color {
                                    FastColor {}
                                }

                                Behavior on scale {
                                    PressAnim {}
                                }
                            }

                            Text {
                                id: count

                                anchors.centerIn: parent
                                visible: flipper.modelData === 0
                                textFormat: Text.PlainText
                                text: I18n.t("%1 / %2").arg(Convert.index + 1).arg(Convert.files.length)
                                color: Theme.gta.text
                                style: Text.Outline
                                styleColor: Theme.gta.outline
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.normal
                                font.weight: Theme.weight.bold
                                font.features: ({
                                        tnum: 1
                                    })
                            }

                            MouseArea {
                                id: flipTap

                                readonly property bool hovered: containsMouse

                                onClicked: Convert.flip(flipper.modelData)

                                anchors.fill: parent
                                enabled: flipper.modelData !== 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: Convert.files.length > 0 ? I18n.t(Convert.formats[Convert.choice].about) : I18n.t("From a browser or a file manager")
                    wrapMode: Text.Wrap
                    color: Theme.gta.soft
                    style: Text.Outline
                    styleColor: Theme.gta.outline
                    font.family: Theme.font
                    font.pixelSize: Theme.gta.hint
                }
            }
        }

        // The mission banner.
        Item {
            id: banner

            readonly property bool up: Convert.result !== ""
            readonly property color tone: win.outcome === "passed" ? Theme.gta.gold : Theme.gta.red

            anchors.fill: parent
            opacity: banner.up ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: banner.up ? Theme.duration.expressiveDefaultEffects : Theme.duration.normal
                }
            }

            Rectangle {
                id: band

                width: parent.width
                height: Theme.gta.bandHeight
                y: parent.height * Theme.gta.bandAt - height / 2
                color: Theme.gta.band

                transform: Scale {
                    origin.y: band.height / 2
                    yScale: banner.up ? 1 : 0

                    Behavior on yScale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: banner.up ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: band
                spacing: Theme.spacing.small

                // The title is fixed artwork made with Pricedown: its licence allows shipping a picture, not the font.
                Item {
                    id: title

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: art.implicitWidth * height / Math.max(1, art.implicitHeight)
                    height: Theme.gta.title
                    opacity: banner.up ? 1 : 0
                    scale: banner.up ? 1 : Theme.gta.titleFrom
                    layer.enabled: opacity < 1

                    layer.effect: MotionBlur {
                        settled: title.opacity
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: banner.up ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                        }
                    }

                    Image {
                        id: art

                        anchors.fill: parent
                        visible: false
                        source: win.outcome === "passed" ? "mission-passed.png" : "mission-failed.png"
                        mipmap: true
                    }

                    // The artwork is white, so the colours stay Theme tokens.
                    MultiEffect {
                        anchors.fill: art
                        source: art
                        colorization: 1
                        colorizationColor: banner.tone
                        shadowEnabled: true
                        shadowColor: Theme.gta.outline
                        shadowBlur: Theme.gta.shadowBlur
                        shadowHorizontalOffset: Theme.gta.shadowOffset
                        shadowVerticalOffset: Theme.gta.shadowOffset
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: Convert.headline
                    color: Theme.gta.text
                    style: Text.Outline
                    styleColor: Theme.gta.outline
                    font.family: Theme.font
                    font.pixelSize: Theme.gta.headline
                    font.weight: Theme.weight.bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.PlainText
                    text: Convert.detail
                    color: Theme.gta.soft
                    style: Text.Outline
                    styleColor: Theme.gta.outline
                    font.family: Theme.font
                    font.pixelSize: Theme.gta.detail
                }
            }
        }
    }
}
