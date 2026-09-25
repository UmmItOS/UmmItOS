pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import ".."

OverlayWindow {
    id: picker

    shown: Wallpapers.pickerOpen
    name: "wallpaper-picker"

    readonly property int focusedWidth: 420
    readonly property int focusedHeight: 236
    readonly property real shrink: 0.5

    property string filter: ""

    // Folder paths end in "/"; ".." goes back up.
    property string folder: Wallpapers.dir
    readonly property bool atRoot: folder === Wallpapers.dir
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
            return "No match";
        if (entry === "..")
            return "Back";
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

    readonly property string focusedPath: matches[list.currentIndex] ?? ""

    // The rescan lands after the jump to the current one; land again.
    Connections {
        target: Wallpapers

        function onListChanged(): void {
            if (picker.shown && picker.filter === "")
                picker.land();
        }
    }

    // Snap, or the carousel animates through every card between.
    function land(): void {
        const actual = Wallpapers.actual;
        folder = actual.startsWith(Wallpapers.dir + "/") ? actual.slice(0, actual.lastIndexOf("/")) : Wallpapers.dir;
        const i = Math.max(0, matches.indexOf(actual));
        list.currentIndex = i;
        list.positionViewAtIndex(i, PathView.Center);
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

    anchors.top: false
    implicitHeight: 460
    color: "transparent"

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
                position: 0.45
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Wallpapers.pickerOpen = false
    }

    FocusScope {
        opacity: Math.min(1, picker.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * picker.reveal

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Wallpapers.pickerOpen = false
        Keys.onLeftPressed: list.decrementCurrentIndex()
        Keys.onRightPressed: list.incrementCurrentIndex()
        Keys.onReturnPressed: picker.apply(list.currentIndex)

        // The name doubles as the search field.
        Column {
            id: meta

            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: Theme.padding.extraLarge * 2
                bottomMargin: Theme.padding.extraLarge
            }
            spacing: Theme.spacing.extraSmall
            width: picker.width / 2

            Text {
                width: parent.width
                visible: search.text === ""
                text: picker.labelOf(picker.focusedPath)
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.extraLarge
                font.bold: true
                elide: Text.ElideRight
            }

            TextInput {
                id: search

                width: parent.width
                clip: true
                visible: text !== ""
                color: Theme.accentText
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.extraLarge
                font.bold: true
                focus: true

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
            }

            Row {
                spacing: Theme.spacing.medium

                Text {
                    text: picker.matches.length === 0 ? "—" : (list.currentIndex + 1) + " of " + picker.matches.length
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.features: ({
                            tnum: 1
                        })
                }

                // Where you are, when it is not the top.
                Text {
                    visible: search.text === "" && !picker.atRoot
                    text: picker.folder.slice(Wallpapers.dir.length + 1) + "  ·  Backspace to go up"
                    color: Theme.accentText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                }

                Text {
                    opacity: search.text === "" ? 1 : 0
                    text: "type to filter"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.smaller
                    font.weight: Theme.weight.medium
                    font.letterSpacing: Theme.tracking.wide

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }
                }
            }
        }

        PathView {
            id: list

            anchors {
                left: parent.left
                right: parent.right
                bottom: meta.top
                bottomMargin: Theme.spacing.extraLargeIncreased
            }
            height: picker.focusedHeight + 40
            model: picker.matches
            clip: true

            transform: Rotation {
                id: page

                origin.x: page.hinge < 0 ? list.width : 0
                origin.y: list.height / 2
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                property int hinge: 1
            }

            ParallelAnimation {
                id: turn

                function open(direction: int): void {
                    page.hinge = direction;
                    swing.from = direction * 80;
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

            // PathView wraps around at both ends; ListView cannot.
            pathItemCount: Math.max(3, Math.floor(width / (picker.focusedWidth * 0.72)))
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            snapMode: PathView.SnapToItem
            movementDirection: PathView.Shortest
            highlightMoveDuration: Theme.duration.expressiveDefaultSpatial

            // Debounced so a held arrow key does not decode every image.
            onCurrentIndexChanged: previewDebounce.restart()

            Timer {
                id: previewDebounce
                interval: 140
                onTriggered: {
                    const path = picker.matches[list.currentIndex];
                    if (path && path !== ".." && !picker.isFolder(path))
                        Wallpapers.preview(path);
                }
            }

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
                    value: -18
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

                Image {
                    id: glowSource

                    anchors.fill: card
                    visible: false
                    source: cell.isUp ? "" : "file://" + picker.coverOf(cell.modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: Theme.cardGlow.sourceWidth
                }

                MultiEffect {
                    anchors.fill: card
                    anchors.margins: -Theme.cardGlow.spread
                    source: glowSource
                    visible: glowSource.status === Image.Ready
                    blurEnabled: true
                    blurMax: Theme.cardGlow.blur
                    blur: 1
                    opacity: cell.focused ? Theme.cardGlow.alphaFocused : Theme.cardGlow.alpha

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultSpatial
                        }
                    }
                }

                ClippingRectangle {
                    id: card

                    anchors.centerIn: parent
                    implicitWidth: picker.focusedWidth
                    implicitHeight: picker.focusedHeight
                    radius: Theme.rounding.large
                    color: cell.isUp ? Theme.bgTray : "transparent"
                    opacity: cell.focused ? 1 : 0.62

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveDefaultEffects
                        }
                    }

                    Image {
                        anchors.fill: parent
                        visible: !cell.isUp
                        opacity: cell.isFolder ? 0.45 : 1
                        source: cell.isUp ? "" : "file://" + picker.coverOf(cell.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: picker.focusedWidth
                        sourceSize.height: picker.focusedHeight
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
                            width: picker.focusedWidth - Theme.padding.large * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
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
                            margins: Theme.padding.medium
                        }
                        visible: cell.confirmed
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: Theme.accentText
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        if (picker.pointerMoved(this, mouse.x, mouse.y))
                            list.currentIndex = cell.index;
                    }
                    onClicked: picker.apply(cell.index)
                }
            }
        }
    }
}
