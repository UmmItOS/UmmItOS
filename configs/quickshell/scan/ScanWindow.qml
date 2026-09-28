pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../bar"

// The codes found on the screen, each washed and labelled, and everything about the picked one beside them.
OverlayWindow {
    id: win

    shown: Scan.open
    name: "scan"
    screen: Scan.screen
    scrim: Theme.shade.normal

    // The code the panel describes; Tab, the arrows or a label click move it.
    property int current: 0
    readonly property int count: Scan.codes.length
    readonly property var code: Scan.codes[current] ?? null
    // The side holding fewer codes, or the one away from the picked code on a tie.
    readonly property bool panelLeft: {
        const mid = c => c.x + c.w / 2 < width / 2;
        const left = Scan.codes.filter(mid).length, right = count - left;
        if (left !== right)
            return left < right;
        return code ? !mid(code) : false;
    }
    property bool revealed: false
    // A hidden Wi-Fi password stays hidden in the raw text too.
    readonly property bool hiding: code?.kind === "wifi" && code.password !== "" && !revealed

    function step(by: int): void {
        current = (current + by + count) % Math.max(1, count);
    }

    function actOnCurrent(): void {
        if (code)
            Scan.act(code);
    }

    function glyph(kind: string): string {
        return ({
                link: "link",
                mailto: "mail",
                tel: "call",
                geo: "location_on",
                wifi: "wifi"
            })[kind] ?? "notes";
    }

    function verb(kind: string): string {
        return ({
                link: "Open",
                mailto: "Write",
                tel: "Call",
                geo: "Map",
                wifi: "Connect"
            })[kind] ?? "Copy";
    }

    // What each symbology is, only for the ones zbar reports; others show just their name.
    function about(format: string): string {
        if (format === "QR-Code")
            return "A square 2D code that cameras read. It can hold a link, text, a Wi-Fi login, a phone number or a place.";
        if (/^(EAN|UPC|ISBN)/.test(format))
            return "A retail barcode: the digits identify a product or a book.";
        if (/^(CODE-|CODABAR|I2\/5|DataBar)/.test(format))
            return "A one-dimensional barcode, common on labels, tickets and parcels.";
        return "";
    }

    // UTF-8 bytes, as a string of byte-valued characters.
    function utf8(text: string): string {
        return unescape(encodeURIComponent(text));
    }

    function hexDump(text: string): string {
        const bytes = utf8(text);
        const shown = bytes.slice(0, Theme.scan.hexBytes);
        const columns = Theme.scan.hexColumns;
        const rows = [];
        for (let i = 0; i < shown.length; i += columns) {
            const row = Array.from(shown.slice(i, i + columns)).map(c => c.charCodeAt(0));
            const hex = row.map(b => b.toString(16).toUpperCase().padStart(2, "0")).join(" ");
            const ascii = row.map(b => b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : "·").join("");
            rows.push(hex.padEnd(columns * 3 - 1) + "   " + ascii);
        }
        if (bytes.length > shown.length)
            rows.push("… " + (bytes.length - shown.length) + " more bytes");
        return rows.join("\n");
    }

    Binding {
        target: Scan
        property: "showing"
        value: win.visible
    }

    onOpened: {
        current = 0;
        revealed = false;
        details.contentY = 0;
        stage.forceActiveFocus();
    }

    onCurrentChanged: {
        revealed = false;
        details.contentY = 0;
        swap.restart();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Scan.open = false
    }

    component Heading: Text {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing.medium
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.smaller
        font.weight: Theme.weight.bold
    }

    component Value: TextEdit {
        Layout.fillWidth: true
        textFormat: TextEdit.PlainText
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        color: Theme.fg
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentOn
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
    }

    // A label over its value; the value can be selected and copied.
    component Field: ColumnLayout {
        id: field

        property string label
        property string value
        // Raw keys (a link's query) read as data, not as titles.
        property bool code: false

        Layout.fillWidth: true
        spacing: Theme.spacing.hair

        Text {
            Layout.fillWidth: true
            text: field.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.dim
            font.family: field.code ? Theme.fontMono : Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }

        Value {
            text: field.value
        }
    }

    // Keys live here, above the codes and the panel, so a click into the text keeps them working.
    Item {
        id: stage

        anchors.fill: parent
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal
        focus: true

        Keys.onEscapePressed: Scan.open = false
        Keys.onTabPressed: win.step(1)
        Keys.onBacktabPressed: win.step(-1)
        Keys.onRightPressed: win.step(1)
        Keys.onLeftPressed: win.step(-1)
        Keys.onReturnPressed: win.actOnCurrent()
        Keys.onEnterPressed: win.actOnCurrent()

        Repeater {
            model: Scan.codes

            Item {
                id: found

                required property var modelData
                required property int index

                readonly property bool picked: win.current === found.index

                anchors.fill: parent
                // The picked code and its label stay above the panel.
                z: found.picked ? 2 : 0

                // Hyprland blurs the screen behind, so the label and the panel identify the code.
                Rectangle {
                    id: wash

                    x: found.modelData.x - Theme.scan.reach
                    y: found.modelData.y - Theme.scan.reach
                    width: found.modelData.w + Theme.scan.reach * 2
                    height: found.modelData.h + Theme.scan.reach * 2
                    radius: Theme.rounding.large
                    color: Theme.accent
                    opacity: found.picked ? Theme.scan.tintPeak : Theme.scan.tint

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }

                Rectangle {
                    id: label

                    readonly property real below: wash.y + wash.height + Theme.spacing.small

                    x: Math.max(Theme.padding.large, Math.min(wash.x + wash.width / 2 - width / 2, win.width - width - Theme.padding.large))
                    // Below the code, above it when the screen ends first.
                    y: below + height > win.height - Theme.padding.large ? Math.max(Theme.padding.large, wash.y - height - Theme.spacing.small) : below
                    width: Math.min(Theme.scan.card, row.implicitWidth + Theme.padding.large * 2)
                    height: Theme.control.field
                    radius: Theme.rounding.full
                    color: found.picked ? Theme.accent : pick.containsMouse ? Theme.bgTray : Theme.bgAlt
                    scale: pick.pressed ? Theme.pressScale : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curve.standard
                        }
                    }

                    RowLayout {
                        id: row

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, label.width - Theme.padding.large * 2)
                        spacing: Theme.spacing.small

                        MaterialIcon {
                            text: win.glyph(found.modelData.kind)
                            color: found.picked ? Theme.accentOn : Theme.accentText
                            size: Theme.icon.small
                        }

                        Text {
                            Layout.fillWidth: true
                            text: found.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: found.picked ? Theme.accentOn : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            font.weight: Theme.weight.medium
                        }
                    }

                    MouseArea {
                        id: pick

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.current = found.index
                    }
                }
            }
        }

        Surface {
            id: panel

            readonly property real room: parent.height - Theme.barHeight - Theme.spacing.small - Theme.padding.large

            y: Theme.barHeight + Theme.spacing.small
            x: win.panelLeft ? Theme.padding.large : win.width - width - Theme.padding.large
            z: 1
            width: Theme.scan.panel
            // As tall as its content, up to the screen; then the details scroll.
            height: Math.min(room, head.implicitHeight + sections.implicitHeight + foot.implicitHeight + Theme.spacing.large * 2 + Theme.padding.extraLarge * 2)
            radius: Theme.rounding.extraLarge
            tone: Theme.scrim(Theme.panelTint)
            lift: Theme.lift.panel
            visible: win.code !== null

            // Only once shown, so a new scan does not slide the panel in from the last side.
            Behavior on x {
                enabled: win.shown && win.reveal >= 1

                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasized
                }
            }

            // Swallow clicks so they do not reach the dismiss handler.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.padding.extraLarge
                }
                spacing: Theme.spacing.large

                RowLayout {
                    id: head

                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    Rectangle {
                        implicitWidth: Theme.control.button
                        implicitHeight: Theme.control.button
                        radius: Theme.rounding.full
                        color: Theme.accent

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: win.glyph(win.code?.kind ?? "")
                            color: Theme.accentOn
                            fill: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: win.code?.type ?? ""
                            color: Theme.fg
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.large
                            font.weight: Theme.weight.bold
                        }

                        Text {
                            visible: win.count > 1
                            text: "Code " + (win.current + 1) + " of " + win.count
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                            font.features: ({
                                    tnum: 1
                                })
                        }
                    }
                }

                // A plain clip: the panel's padding keeps it clear of the rounded corners.
                Flickable {
                    id: details

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: sections.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: Theme.spacing.extraSmall
                            radius: width / 2
                            color: Theme.dim
                        }
                        background: null
                    }

                    ColumnLayout {
                        id: sections

                        width: details.width - Theme.spacing.medium
                        spacing: Theme.spacing.medium
                        transform: Translate {
                            id: lift
                        }

                        // Faded and lifted in whenever the picked code changes.
                        ParallelAnimation {
                            id: swap

                            NumberAnimation {
                                target: sections
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.duration.expressiveDefaultEffects
                            }
                            NumberAnimation {
                                target: lift
                                property: "y"
                                from: Theme.spacing.medium
                                to: 0
                                duration: Theme.duration.expressiveDefaultSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curve.emphasizedDecel
                            }
                        }

                        Heading {
                            Layout.topMargin: 0
                            visible: (win.code?.fields.length ?? 0) > 0
                            text: "Encoded data"
                        }

                        Repeater {
                            model: win.code?.fields ?? []

                            Field {
                                required property var modelData

                                label: modelData[0]
                                value: modelData[1]
                                code: modelData[2] === true
                            }
                        }

                        // A scanned password is the one field worth not showing until asked.
                        RowLayout {
                            Layout.fillWidth: true
                            visible: win.code?.kind === "wifi" && win.code.password !== ""
                            spacing: Theme.spacing.small

                            Field {
                                label: "Password"
                                value: win.revealed ? (win.code?.password ?? "") : "••••••••"
                            }

                            BarButton {
                                Layout.alignment: Qt.AlignBottom
                                icon: win.revealed ? "visibility_off" : "visibility"
                                baseColor: Theme.dim
                                onClicked: win.revealed = !win.revealed
                            }
                        }

                        Heading {
                            text: "Content"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: content.implicitHeight + Theme.padding.medium * 2
                            radius: Theme.rounding.medium
                            color: Theme.glass

                            Value {
                                id: content

                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: Theme.padding.medium
                                }
                                text: win.hiding ? win.code.masked : (win.code?.data ?? "")
                                wrapMode: TextEdit.WrapAnywhere
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSize.smaller
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: {
                                const data = win.code?.data ?? "";
                                const chars = Array.from(data).length;
                                const bytes = win.utf8(data).length;
                                return chars + (chars === 1 ? " character" : " characters") + (bytes !== chars ? " · " + bytes + " bytes" : "");
                            }
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                            font.features: ({
                                    tnum: 1
                                })
                        }

                        // The code as it was on screen, cut from the scan's own picture.
                        ClippingRectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: picture.width
                            implicitHeight: Theme.scan.picture
                            radius: Theme.rounding.medium
                            color: "transparent"

                            Image {
                                id: picture

                                width: Math.min(sections.width, Theme.scan.picture * (win.code ? win.code.pixels.width / Math.max(1, win.code.pixels.height) : 1))
                                height: Theme.scan.picture
                                source: win.code ? Scan.picture : ""
                                sourceClipRect: win.code?.pixels ?? Qt.rect(0, 0, 0, 0)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }

                        Heading {
                            text: "Format"
                        }

                        Field {
                            label: "Type"
                            value: win.code?.format === "QR-Code" ? "QR Code" : (win.code?.format ?? "")
                        }

                        Value {
                            visible: text !== ""
                            text: win.about(win.code?.format ?? "")
                            color: Theme.dim
                            font.pixelSize: Theme.fontSize.smaller
                        }

                        Field {
                            label: "Orientation"
                            value: ({
                                    UP: "Upright",
                                    RIGHT: "Turned right",
                                    DOWN: "Upside down",
                                    LEFT: "Turned left"
                                })[win.code?.orientation ?? ""] ?? "Unknown"
                        }

                        Field {
                            label: "Size on screen"
                            value: win.code ? Math.round(win.code.w) + " × " + Math.round(win.code.h) + " px" : ""
                        }

                        Heading {
                            text: "Hex dump"
                        }

                        Value {
                            text: win.hiding ? "Reveal the password to see the bytes." : win.hexDump(win.code?.data ?? "")
                            color: win.hiding ? Theme.dim : Theme.fg
                            wrapMode: TextEdit.NoWrap
                            font.family: win.hiding ? Theme.font : Theme.fontMono
                            font.pixelSize: Theme.fontSize.small
                        }
                    }
                }

                ColumnLayout {
                    id: foot

                    Layout.fillWidth: true
                    spacing: Theme.spacing.small

                    Text {
                        Layout.fillWidth: true
                        text: (win.count > 1 ? "Tab for the next code · " : "") + "Enter to " + win.verb(win.code?.kind ?? "").toLowerCase() + " · Esc to close"
                        color: Theme.dim
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Theme.spacing.small

                        Action {
                            visible: win.code?.kind !== "text"
                            icon: "content_copy"
                            label: "Copy"
                            onClicked: Scan.copy(win.code.data)
                        }

                        Action {
                            visible: win.code?.kind === "wifi" && win.code.password !== ""
                            icon: "key"
                            label: "Copy password"
                            onClicked: Scan.copy(win.code.password)
                        }

                        Action {
                            primary: true
                            icon: win.code?.kind === "link" ? "open_in_new" : win.code?.kind === "text" ? "content_copy" : win.glyph(win.code?.kind ?? "")
                            label: win.verb(win.code?.kind ?? "")
                            onClicked: win.actOnCurrent()
                        }
                    }
                }
            }
        }
    }
}
