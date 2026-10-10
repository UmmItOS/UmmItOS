pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    // A picture is copied again; a folder is entered; the up card goes back.
    function accept(): void {
        const shot = Gallery.shots[grid.currentIndex];
        if (!shot || Gallery.leaving)
            return;
        if (shot.kind === "file")
            Gallery.copy(shot.path);
        else if (shot.kind === "dir")
            Gallery.enter(shot.path);
        else
            Gallery.up();
    }

    // The pseudo-random 0..1 of a card and a salt: the same card always starts in the same place.
    function rnd(index: int, salt: real): real {
        const v = Math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
        return v - Math.floor(v);
    }

    // Cards made while the sheet arrives fly in; ones made by scrolling later just appear.
    property bool arriving: false
    readonly property var shots: Gallery.shots
    readonly property int pictures: shots.filter(s => s.kind === "file").length

    readonly property bool searching: Gallery.query !== ""

    onOpened: {
        grid.currentIndex = 0;
        arriving = true;
        arrival.restart();
        search.text = "";
        search.forceActiveFocus();
    }

    shown: Gallery.open
    name: "gallery"
    scrim: Theme.shade.heavy

    // A new folder's cards arrive like the first ones, and the folder just left is picked.
    Connections {
        function onShotsChanged(): void {
            if (!Gallery.open || Gallery.loading)
                return;
            const at = Gallery.shots.findIndex(s => s.path === Gallery.came);
            grid.currentIndex = at >= 0 ? at : 0;
            win.arriving = Gallery.flyIn;
            arrival.restart();
        }

        target: Gallery
    }

    Timer {
        id: debounce

        onTriggered: {
            if (search.text.trim() !== Gallery.query)
                Gallery.setQuery(search.text);
        }

        interval: Theme.duration.decodeDebounce
    }

    Timer {
        id: arrival

        onTriggered: win.arriving = false

        interval: Theme.gallery.arrival
    }

    MouseArea {
        onClicked: Gallery.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

        Keys.onPressed: event => {
            const page = Math.max(1, Math.floor(grid.height / grid.cellHeight)) * Math.floor(grid.width / grid.cellWidth);
            const last = Gallery.shots.length - 1;
            if (event.key === Qt.Key_PageDown)
                grid.currentIndex = Math.min(last, grid.currentIndex + page);
            else if (event.key === Qt.Key_PageUp)
                grid.currentIndex = Math.max(0, grid.currentIndex - page);
            else if (event.key === Qt.Key_Home)
                grid.currentIndex = 0;
            else if (event.key === Qt.Key_End)
                grid.currentIndex = Math.max(0, last);
            else
                return;
            event.accepted = true;
        }

        anchors.fill: parent
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal
        focus: true

        ColumnLayout {
            id: head

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Theme.spacing.extraLarge * 2
                leftMargin: Theme.spacing.extraLarge * 3
                rightMargin: Theme.spacing.extraLarge * 3
            }

            spacing: Theme.spacing.extraSmall

            Text {
                text: I18n.t("Screenshots")
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.query
                font.weight: Theme.weight.bold
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: win.searching ? I18n.t("%1 matches for %2").arg(win.pictures).arg(Gallery.query) : I18n.t("%1 screenshots in %2").arg(win.pictures).arg(Settings.tilde(Gallery.folder))
                color: Theme.dim
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
                opacity: Gallery.loading ? 0 : 1
            }

            // Type to search the text inside the pictures.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing.medium
                implicitHeight: Theme.control.pill
                radius: Theme.rounding.full
                color: Theme.bgTray

                MaterialIcon {
                    id: lens

                    anchors {
                        left: parent.left
                        leftMargin: Theme.spacing.large
                        verticalCenter: parent.verticalCenter
                    }

                    text: "search"
                    color: Theme.dim
                    size: Theme.icon.small
                }

                TextInput {
                    id: search

                    Keys.onEscapePressed: {
                        if (text !== "")
                            text = "";
                        else
                            Gallery.open = false;
                    }

                    Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                    Keys.onRightPressed: grid.moveCurrentIndexRight()
                    Keys.onUpPressed: grid.moveCurrentIndexUp()
                    Keys.onDownPressed: grid.moveCurrentIndexDown()
                    Keys.onReturnPressed: win.accept()
                    Keys.onEnterPressed: win.accept()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Backspace && text === "") {
                            Gallery.up();
                            event.accepted = true;
                        }
                    }

                    onTextChanged: debounce.restart()

                    anchors {
                        left: lens.right
                        right: parent.right
                        leftMargin: Theme.spacing.medium
                        rightMargin: Theme.spacing.large
                        verticalCenter: parent.verticalCenter
                    }

                    color: Theme.fg
                    selectByMouse: true
                    clip: true
                    focus: true
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: I18n.t("Search the text inside screenshots")
                        color: Theme.dim
                        font: search.font
                    }
                }
            }

            // How far the reading of every picture's text has got.
            Item {
                id: reading

                readonly property real done: Gallery.total > 0 ? Gallery.indexed / Gallery.total : 1

                Layout.fillWidth: true
                implicitHeight: readingText.implicitHeight
                opacity: done < 1 ? 1 : 0
                visible: opacity > 0
                layer.enabled: opacity < 1

                layer.effect: MotionBlur {
                    settled: reading.opacity
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }

                Text {
                    id: readingText

                    textFormat: Text.PlainText
                    text: I18n.t("Reading text from screenshots: %1 of %2").arg(Gallery.indexed).arg(Gallery.total)
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.small
                    font.features: ({
                            tnum: 1
                        })
                }
            }
        }

        GridView {
            id: grid

            anchors {
                top: head.bottom
                left: parent.left
                right: parent.right
                bottom: foot.top
                topMargin: Theme.spacing.extraLarge
                leftMargin: Theme.spacing.extraLarge * 3 - Theme.spacing.medium
                rightMargin: Theme.spacing.extraLarge * 3 - Theme.spacing.medium
                bottomMargin: Theme.spacing.large
            }

            clip: true
            opacity: Gallery.leaving ? 0 : 1
            // The cards rush toward you as the folder opens.
            scale: Gallery.leaving ? Theme.gallery.enterScale : 1
            transformOrigin: Item.Center
            cellWidth: Math.floor(width / Math.min(Theme.gallery.maxColumns, Math.max(Theme.gallery.minColumns, Math.floor(width / Theme.gallery.cellMin))))
            cellHeight: Math.round(cellWidth * Theme.gallery.ratio) + Theme.gallery.label
            model: Gallery.shots
            currentIndex: 0
            highlightMoveDuration: Theme.duration.expressiveFastEffects
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: cellHeight
            preferredHighlightEnd: height - cellHeight * 2

            Behavior on opacity {
                FastFade {}
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Gallery.leaving ? Theme.curve.emphasizedAccel : Theme.curve.emphasizedDecel
                }
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool active: GridView.isCurrentItem
                readonly property bool isFile: modelData.kind === "file"
                // 1 where it started, scattered; 0 in its place.
                property real arrive: win.arriving ? 1 : 0

                width: grid.cellWidth
                height: grid.cellHeight
                scale: cell.active ? Theme.gallery.activeScale : 1
                opacity: 1 - cell.arrive
                layer.enabled: cell.arrive > 0

                layer.effect: MotionBlur {
                    settled: 1 - cell.arrive
                }

                transform: [
                    Translate {
                        x: (win.rnd(cell.index, 1) - 0.5) * grid.width * Theme.gallery.scatter * cell.arrive
                        y: (win.rnd(cell.index, 2) - 0.5) * grid.height * Theme.gallery.scatter * cell.arrive
                    },
                    Rotation {
                        origin.x: cell.width / 2
                        origin.y: cell.height / 2
                        angle: (win.rnd(cell.index, 3) - 0.5) * 2 * Theme.gallery.tilt * cell.arrive
                    }
                ]

                Component.onCompleted: {
                    if (cell.arrive > 0)
                        landing.start();
                }

                SequentialAnimation {
                    id: landing

                    PauseAnimation {
                        duration: Theme.reduceMotion ? 0 : Math.min(cell.index, 40) * Theme.gallery.stagger
                    }

                    NumberAnimation {
                        target: cell
                        property: "arrive"
                        to: 0
                        duration: Theme.duration.expressiveDefaultSpatial * 2
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                    }
                }

                Surface {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.small
                    }

                    radius: Theme.rounding.extraLarge
                    tone: Theme.bgTray
                    opacity: cell.active ? 1 : 0

                    layer.enabled: cell.active

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.accent
                        shadowBlur: 1
                        shadowOpacity: Theme.gallery.glow
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }

                    Behavior on opacity {
                        FastFade {}
                    }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.medium
                    }

                    spacing: Theme.spacing.small

                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.rounding.large
                        color: Theme.bgAlt

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !cell.isFile
                            text: cell.modelData.kind === "up" ? "arrow_upward" : "folder"
                            color: cell.active ? Theme.accentText : Theme.dim
                            size: Theme.icon.huge
                            fill: 1

                            Behavior on color {
                                FastColor {}
                            }
                        }

                        // Sharpens out of a blur as it decodes.
                        Image {
                            id: thumb

                            anchors.fill: parent
                            visible: cell.isFile
                            source: cell.isFile ? "file://" + cell.modelData.path : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: grid.cellWidth * 2
                            opacity: status === Image.Ready ? 1 : 0
                            layer.enabled: opacity < 1

                            layer.effect: MotionBlur {
                                settled: thumb.opacity
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveDefaultEffects
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: cell.modelData.kind === "up" ? I18n.t("Back") : cell.modelData.name
                            color: cell.active ? Theme.fg : Theme.dim
                            elide: Text.ElideMiddle
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            font.weight: cell.active ? Theme.weight.medium : Theme.weight.regular
                        }

                        Text {
                            visible: cell.isFile
                            textFormat: Text.PlainText
                            text: Qt.formatDateTime(new Date(cell.modelData.time), I18n.t("d MMM, HH:mm"))
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }
                    }
                }

                MouseArea {
                    onPositionChanged: mouse => {
                        if (win.pointerMoved(this, mouse.x, mouse.y))
                            grid.currentIndex = cell.index;
                    }

                    onClicked: {
                        grid.currentIndex = cell.index;
                        win.accept();
                    }

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // While the folder is read: a spinner that sharpens in and blurs out.
        Column {
            id: loader

            anchors.centerIn: grid
            spacing: Theme.spacing.medium
            opacity: Gallery.loading || Gallery.leaving ? 1 : 0
            visible: opacity > 0
            layer.enabled: opacity < 1

            layer.effect: MotionBlur {
                settled: loader.opacity
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }

            Spinner {
                anchors.horizontalCenter: parent.horizontalCenter
                size: Theme.icon.huge
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("Loading screenshots")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
            }
        }

        FlyoutEmpty {
            anchors.fill: grid
            visible: !Gallery.loading && !Gallery.leaving && Gallery.shots.length === 0
            icon: "screenshot_region"
            text: win.searching ? I18n.t("No match") : I18n.t("No screenshots yet")
        }

        Text {
            id: foot

            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: Theme.spacing.extraLarge
            }

            text: I18n.t("Type to search · Enter to copy or open · Esc to close")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            opacity: Gallery.shots.length > 0 ? 1 : 0
        }
    }
}
