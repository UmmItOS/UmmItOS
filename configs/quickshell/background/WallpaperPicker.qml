pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import ".."

OverlayWindow {
    id: picker

    readonly property int focusedWidth: Theme.picker.cardWidth
    readonly property int focusedHeight: Theme.picker.cardHeight
    readonly property real shrink: Theme.picker.shrink

    property string filter: ""

    // Folder paths end in "/"; ".." goes back up.
    property string folder: Wallpapers.dir
    readonly property bool atRoot: folder === Wallpapers.dir
    // The open folder relative to the wallpaper dir; "" at the top.
    readonly property string here: folder.slice(Wallpapers.dir.length + 1)

    readonly property var matches: {
        if (filter !== "")
            return Wallpapers.list.filter(p => Wallpapers.name(p).toLowerCase().includes(filter.toLowerCase()));
        const base = folder + "/";
        const dirs = new Set();
        const files = [];
        for (const p of Wallpapers.list) {
            if (!p.startsWith(base))
                continue;
            const rest = p.slice(base.length);
            const slash = rest.indexOf("/");
            if (slash < 0)
                files.push(p);
            else
                dirs.add(base + rest.slice(0, slash) + "/");
        }
        const byName = (a, b) => a.localeCompare(b, undefined, {
                numeric: true
            });
        return [...(atRoot ? [] : [".."]), ...[...dirs].sort(byName), ...files.sort(byName)];
    }

    readonly property string focusedPath: matches[list.currentIndex] ?? ""

    function isFolder(entry: string): bool {
        return entry.endsWith("/");
    }

    // The image a folder card shows: the first one anywhere inside it.
    function coverOf(entry: string): string {
        if (entry === "..")
            return "";
        return isFolder(entry) ? (Wallpapers.list.find(p => p.startsWith(entry)) ?? "") : entry;
    }

    function labelOf(entry: string): string {
        if (entry === "")
            return I18n.t("No match");
        if (entry === "..")
            return I18n.t("Back");
        if (isFolder(entry))
            return entry.slice(0, -1).slice(entry.slice(0, -1).lastIndexOf("/") + 1);
        return Wallpapers.name(entry);
    }

    function enter(entry: string): void {
        folder = entry.slice(0, -1);
        list.currentIndex = 0;
        list.positionViewAtIndex(0, PathView.Center);
        turn.open(1);
    }

    // Back up one level, landing on the folder just left.
    function up(): void {
        if (atRoot)
            return;
        const left = folder + "/";
        folder = folder.slice(0, folder.lastIndexOf("/"));
        const i = Math.max(0, matches.indexOf(left));
        list.currentIndex = i;
        list.positionViewAtIndex(i, PathView.Center);
        turn.open(-1);
    }

    // Snap, or the carousel animates through every card between.
    function land(): void {
        const actual = Wallpapers.actual;
        folder = actual.startsWith(Wallpapers.dir + "/") ? actual.slice(0, actual.lastIndexOf("/")) : Wallpapers.dir;
        const i = Math.max(0, matches.indexOf(actual));
        list.currentIndex = i;
        list.positionViewAtIndex(i, PathView.Center);
    }

    function apply(index: int): void {
        const entry = matches[index] ?? "";
        if (entry === "..")
            return up();
        if (isFolder(entry))
            return enter(entry);
        if (shown && index >= 0 && index < matches.length) {
            previewDebounce.stop();
            Wallpapers.set(matches[index]);
            Wallpapers.pickerOpen = false;
        }
    }

    onOpened: {
        filter = "";
        search.text = "";
        land();
        search.forceActiveFocus();
    }

    // On the flag, not on unmapping, so it does not wait for the exit.
    onShownChanged: {
        if (!shown) {
            // A preview still pending would land after the restore and stick.
            previewDebounce.stop();
            Wallpapers.clearPreview();
        }
    }

    shown: Wallpapers.pickerOpen
    name: "wallpaper-picker"

    anchors.top: false
    implicitHeight: Theme.picker.height
    color: "transparent"

    // The rescan lands after the jump to the current one; land again.
    Connections {
        function onListChanged(): void {
            if (picker.shown && picker.filter === "")
                picker.land();
        }

        target: Wallpapers
    }

    // Enough wash to read type against any wallpaper, no edge, no card.
    Rectangle {
        anchors.fill: parent
        opacity: Math.min(1, picker.reveal)

        gradient: Gradient {
            GradientStop {
                position: 0
                color: "transparent"
            }

            GradientStop {
                position: Theme.picker.fadeAt
                color: Theme.scrim(Theme.picker.fadeAlpha)
            }

            GradientStop {
                position: 1
                color: Theme.scrim(Theme.picker.floorAlpha)
            }
        }
    }

    MouseArea {
        onClicked: Wallpapers.pickerOpen = false

        anchors.fill: parent
    }

    FocusScope {
        Keys.onEscapePressed: Wallpapers.pickerOpen = false
        Keys.onLeftPressed: list.decrementCurrentIndex()
        Keys.onRightPressed: list.incrementCurrentIndex()
        Keys.onReturnPressed: picker.apply(list.currentIndex)

        opacity: Math.min(1, picker.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * picker.reveal

        anchors.fill: parent
        focus: true

        // The name doubles as the search field.
        Column {
            id: meta

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: Theme.spacing.extraLarge * 2
                bottomMargin: Theme.spacing.extraLarge
            }

            spacing: Theme.spacing.extraSmall
            width: picker.width / 2

            Text {
                width: parent.width
                visible: search.text === ""
                textFormat: Text.PlainText
                text: picker.labelOf(picker.focusedPath)
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.extraLarge
                font.bold: true
                elide: Text.ElideRight
            }

            TextInput {
                id: search

                onTextChanged: {
                    picker.filter = text;
                    list.currentIndex = 0;
                }

                Keys.onEscapePressed: Wallpapers.pickerOpen = false
                Keys.onLeftPressed: list.decrementCurrentIndex()
                Keys.onRightPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: picker.apply(list.currentIndex)

                // With no query to delete, Backspace goes up a folder.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backspace && text === "" && !picker.atRoot) {
                        picker.up();
                        event.accepted = true;
                    }
                }

                width: parent.width
                clip: true
                visible: text !== ""
                color: Theme.accentText
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.extraLarge
                font.bold: true
                focus: true
            }

            Row {
                spacing: Theme.spacing.medium

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: picker.matches.length === 0 ? "—" : I18n.t("%1 of %2").arg(list.currentIndex + 1).arg(picker.matches.length)
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller

                    font.features: ({
                            tnum: 1
                        })
                }

                // Where you are, when it is not the top.
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === "" && !picker.atRoot
                    textFormat: Text.PlainText
                    text: I18n.t("%1  ·  Backspace to go up").arg(picker.here)
                    color: Theme.accentText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                }

                // The bar's shuffle draws from here from now on; right-clicking its button does the same.
                Action {
                    id: shuffleHere

                    readonly property bool shown: search.text === "" && !picker.atRoot

                    onClicked: Wallpapers.setFolder(picker.here)

                    anchors.verticalCenter: parent.verticalCenter
                    // Stays laid out until the fade ends, so it leaves before the row closes up.
                    visible: opacity > 0
                    opacity: shown ? 1 : 0
                    // Disabled, Action draws flat whatever primary says.
                    primary: true
                    icon: "shuffle"
                    label: Wallpapers.folder === picker.here ? I18n.t("Shuffling from here") : I18n.t("Shuffle from here")
                    enabled: Wallpapers.folder !== picker.here

                    transform: Scale {
                        origin.x: shuffleHere.width / 2
                        origin.y: shuffleHere.height / 2
                        xScale: shuffleHere.shown ? 1 : Theme.pressScale
                        yScale: xScale

                        Behavior on xScale {
                            NumberAnimation {
                                duration: Theme.duration.expressiveFastSpatial
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: shuffleHere.shown ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                            }
                        }
                    }

                    Behavior on opacity {
                        FastFade {}
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: search.text === "" ? 1 : 0
                    text: I18n.t("type to filter")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                    font.letterSpacing: Theme.tracking.wide

                    Behavior on opacity {
                        FastFade {}
                    }
                }
            }
        }

        PathView {
            id: list

            // Debounced so a held arrow key does not decode every image.
            onCurrentIndexChanged: previewDebounce.restart()

            anchors {
                left: parent.left
                right: parent.right
                bottom: meta.top
                bottomMargin: Theme.spacing.extraLarge
            }

            height: picker.focusedHeight + Theme.picker.headroom
            model: picker.matches
            clip: true

            transform: Rotation {
                id: page

                property int hinge: 1

                origin.x: page.hinge < 0 ? list.width : 0
                origin.y: list.height / 2

                axis {
                    x: 0
                    y: 1
                    z: 0
                }
            }

            // PathView wraps around at both ends; ListView cannot.
            pathItemCount: Math.max(Theme.picker.minCards, Math.floor(width / (picker.focusedWidth * Theme.picker.cardSpan)))
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            movementDirection: PathView.Shortest
            highlightMoveDuration: Theme.duration.expressiveDefaultSpatial

            path: Path {
                startX: 0
                startY: list.height / 2

                PathAttribute {
                    name: "itemScale"
                    value: picker.shrink
                }

                PathAttribute {
                    name: "itemLift"
                    value: 0
                }

                PathLine {
                    x: list.width / 2
                    y: list.height / 2
                }

                PathAttribute {
                    name: "itemScale"
                    value: 1
                }

                PathAttribute {
                    name: "itemLift"
                    value: Theme.picker.focusLift
                }

                PathLine {
                    x: list.width
                    y: list.height / 2
                }

                PathAttribute {
                    name: "itemScale"
                    value: picker.shrink
                }

                PathAttribute {
                    name: "itemLift"
                    value: 0
                }
            }

            delegate: Item {
                id: cell

                required property string modelData
                required property int index

                readonly property bool focused: PathView.isCurrentItem
                readonly property bool isUp: modelData === ".."
                readonly property bool isFolder: picker.isFolder(modelData)
                // A folder counts as confirmed when the wallpaper is inside it.
                readonly property bool confirmed: isFolder ? Wallpapers.actual.startsWith(modelData) : modelData === Wallpapers.actual

                width: picker.focusedWidth
                height: list.height

                scale: PathView.itemScale ?? picker.shrink

                // Translate, not `y`: PathView overwrites y on every update.
                transform: Translate {
                    y: cell.PathView.itemLift ?? 0
                }

                z: focused ? 1 : 0

                ClippingRectangle {
                    id: card

                    anchors.centerIn: parent
                    implicitWidth: picker.focusedWidth
                    implicitHeight: picker.focusedHeight
                    radius: Theme.rounding.large
                    color: cell.isUp ? Theme.bgTray : "transparent"
                    opacity: cell.focused ? 1 : Theme.picker.unfocused

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    Image {
                        id: picture

                        anchors.fill: parent
                        source: cell.isUp ? "" : "file://" + picker.coverOf(cell.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: picker.focusedWidth
                        sourceSize.height: picker.focusedHeight
                    }

                    // As drawn, crop included; the Image's own texture is the uncropped file.
                    ShaderEffectSource {
                        id: pictureShot

                        anchors.fill: parent
                        sourceItem: picture
                        hideSource: true
                        visible: false
                    }

                    ShaderEffect {
                        property var source: pictureShot
                        property size size: Qt.size(width, height)
                        property real radius: card.radius
                        property real spread: Theme.cardFeather

                        anchors.fill: parent
                        visible: !cell.isUp
                        opacity: cell.isFolder ? Theme.picker.folder : 1

                        fragmentShader: "feather.frag.qsb"
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: cell.isFolder || cell.isUp
                        spacing: Theme.spacing.small

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.isUp ? "arrow_upward" : "folder"
                            color: Theme.fg
                            fill: 1
                            size: Theme.icon.huge
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: picker.focusedWidth - Theme.spacing.large * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: picker.labelOf(cell.modelData)
                            color: Theme.fg
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSize.large
                            font.bold: true
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                            margins: Theme.spacing.medium
                        }

                        visible: cell.confirmed
                        implicitWidth: Theme.picker.dot
                        implicitHeight: Theme.picker.dot
                        radius: Theme.picker.dot / 2
                        color: Theme.accentText
                    }
                }

                MouseArea {
                    onPositionChanged: mouse => {
                        if (picker.pointerMoved(this, mouse.x, mouse.y))
                            list.currentIndex = cell.index;
                    }

                    onClicked: picker.apply(cell.index)

                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            ParallelAnimation {
                id: turn

                function open(direction: int): void {
                    page.hinge = direction;
                    swing.from = direction * Theme.picker.swing;
                    restart();
                }

                NumberAnimation {
                    id: swing

                    target: page
                    property: "angle"
                    to: 0
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curve.emphasizedDecel
                }

                NumberAnimation {
                    target: list
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            Timer {
                id: previewDebounce

                onTriggered: {
                    const path = picker.matches[list.currentIndex];
                    if (path && path !== ".." && !picker.isFolder(path))
                        Wallpapers.preview(path);
                }

                interval: Theme.duration.previewDebounce
            }
        }
    }
}
