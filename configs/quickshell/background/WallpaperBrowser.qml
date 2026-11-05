pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."
import "../bar"

// The mouse-first wallpaper chooser from the desktop menu; Alt+W keeps the carousel.
OverlayWindow {
    id: browser

    // The open folder, relative to the wallpaper dir; "" is All.
    property string here: ""
    // The picture under the pointer, once the pointer really moved.
    property string hoverPath: ""

    readonly property var pictures: {
        // The whole subtree, as Shuffle draws from it, so the grid, the count and Shuffle agree.
        const base = Wallpapers.dir + "/" + browser.here + "/";
        const all = browser.here === "" ? Wallpapers.list : Wallpapers.list.filter(p => p.startsWith(base));
        return [...all].sort((a, b) => a.localeCompare(b, undefined, {
                numeric: true
            }));
    }
    // The folder at the top of the selection's path; its children get the second row.
    readonly property string rootFolder: browser.here.split("/")[0]
    readonly property var rail: [
        {
            path: "",
            name: I18n.t("All"),
            depth: 0,
            count: Wallpapers.list.length
        }
    ].concat(Wallpapers.folders.filter(f => f.depth === 0))
    readonly property var subList: browser.rootFolder === "" ? [] : Wallpapers.folders.filter(f => f.path.startsWith(browser.rootFolder + "/")).map(f => ({
                path: f.path,
                name: f.path.slice(browser.rootFolder.length + 1),
                count: f.count
            }))

    onSubListChanged: {
        if (browser.subList.length > 0)
            panel.subKept = browser.subList;
    }

    // On the flag, not on unmapping, so it does not wait for the exit.
    onShownChanged: {
        if (!browser.shown) {
            // A preview still pending would land after the restore and stick.
            previewDebounce.stop();
            browser.hoverPath = "";
            Wallpapers.clearPreview();
        }
    }

    onOpened: {
        browser.here = "";
        keys.forceActiveFocus();
    }

    shown: Wallpapers.browserOpen
    name: "wallpaper-browser"

    MouseArea {
        onClicked: Wallpapers.browserOpen = false

        anchors.fill: parent
    }

    FocusScope {
        id: keys

        Keys.onEscapePressed: Wallpapers.browserOpen = false

        anchors.fill: parent

        Surface {
            id: panel

            // Eased apart from reveal, whose opening curve overshoots.
            property real slide: browser.shown ? 1 : 0
            // 1 while the second chip row is out.
            property real subShift: browser.subList.length > 0 ? 1 : 0
            // The last non-empty row, so it can fade out with its chips still there.
            property var subKept: []

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                topMargin: Theme.barHeight + Theme.spacing.large
                margins: Theme.spacing.large
            }

            width: Theme.browser.drawerWidth
            radius: Theme.rounding.extraLarge
            opacity: Math.min(1, browser.reveal)

            transform: Translate {
                x: (1 - panel.slide) * panel.width * Theme.browser.slideShare
            }

            Behavior on slide {
                NumberAnimation {
                    duration: browser.shown ? Theme.duration.expressiveDefaultSpatial : Theme.duration.expressiveFastSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: browser.shown ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            Behavior on subShift {
                NumberAnimation {
                    duration: Theme.duration.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: browser.subList.length > 0 ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                }
            }

            // Swallows clicks, so only the empty desktop beside the drawer closes it.
            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                id: bar

                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Theme.spacing.large
                }

                spacing: Theme.spacing.medium

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: I18n.t("Wallpaper")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.bold: true
                    elide: Text.ElideRight
                }

                BarButton {
                    onClicked: Wallpapers.setFolder(browser.here)

                    icon: "shuffle"
                    label: I18n.t("Shuffle %1").arg(browser.here === "" ? I18n.t("All") : browser.here.slice(browser.here.lastIndexOf("/") + 1))
                }

                BarButton {
                    onClicked: Wallpapers.browserOpen = false

                    icon: "close"
                    label: "Close"
                }
            }

            Text {
                id: caption

                anchors {
                    left: parent.left
                    right: parent.right
                    top: bar.bottom
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }

                textFormat: Text.PlainText
                text: (browser.pictures.length === 1 ? I18n.t("1 picture · hover to preview, click to set") : I18n.t("%1 pictures · hover to preview, click to set").arg(browser.pictures.length))
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                elide: Text.ElideRight
            }

            Flow {
                id: chips

                anchors {
                    left: parent.left
                    right: parent.right
                    top: caption.bottom
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                    topMargin: Theme.spacing.medium
                }

                spacing: Theme.spacing.small

                Repeater {
                    model: browser.rail

                    delegate: FolderChip {
                        required property var modelData

                        onChosen: path => browser.here = path

                        path: modelData.path
                        title: modelData.name
                        count: modelData.count
                        here: browser.here
                    }
                }
            }

            Flow {
                id: subChips

                anchors {
                    left: parent.left
                    right: parent.right
                    top: chips.bottom
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                    topMargin: Theme.spacing.small
                }

                visible: panel.subShift > 0
                opacity: panel.subShift
                spacing: Theme.spacing.small

                transform: Translate {
                    y: (panel.subShift - 1) * Theme.spacing.medium
                }

                MaterialIcon {
                    text: "subdirectory_arrow_right"
                    size: Theme.icon.small
                    color: Theme.dim
                }

                Repeater {
                    model: panel.subKept

                    delegate: FolderChip {
                        required property var modelData

                        onChosen: path => browser.here = path

                        path: modelData.path
                        title: modelData.name
                        count: modelData.count
                        here: browser.here
                    }
                }
            }

            GridView {
                id: grid

                readonly property int thumbWidth: grid.cellWidth - Theme.spacing.small * 2
                readonly property int thumbHeight: Math.round(grid.thumbWidth * Theme.browser.thumbRatio)

                anchors {
                    left: parent.left
                    right: parent.right
                    top: chips.bottom
                    bottom: parent.bottom
                    margins: Theme.spacing.large
                    topMargin: Theme.spacing.large + panel.subShift * (subChips.implicitHeight + Theme.spacing.small)
                }

                clip: true
                cellWidth: Math.floor(width / Theme.browser.columns)
                cellHeight: grid.thumbHeight + Theme.browser.nameBand + Theme.spacing.small * 2
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: browser.pictures
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.duration.expressiveDefaultEffects
                    }
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Theme.duration.expressiveDefaultSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.emphasizedDecel
                    }
                }

                delegate: Item {
                    id: cell

                    required property string modelData

                    readonly property bool hovered: browser.hoverPath === cell.modelData
                    readonly property bool current: cell.modelData === Wallpapers.actual

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: Wallpapers.name(cell.modelData)
                    Accessible.checkable: true
                    Accessible.checked: cell.current
                    Accessible.onPressAction: pick()

                    function pick(): void {
                        previewDebounce.stop();
                        Wallpapers.set(cell.modelData);
                        Wallpapers.browserOpen = false;
                    }

                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    ClippingRectangle {
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                            topMargin: Theme.spacing.small
                        }

                        width: grid.thumbWidth
                        height: grid.thumbHeight
                        radius: Theme.rounding.large
                        color: Theme.bgTray
                        scale: press.pressed ? Theme.pressScale : cell.hovered ? Theme.browser.hoverScale : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.duration.expressiveFastEffects
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curve.emphasizedDecel
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: grid.thumbWidth
                            sourceSize.height: grid.thumbHeight
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                right: parent.right
                                margins: Theme.spacing.small
                            }

                            implicitWidth: Theme.browser.badge
                            implicitHeight: Theme.browser.badge
                            radius: Theme.rounding.full
                            color: Theme.accent
                            visible: opacity > 0
                            opacity: cell.current ? 1 : 0
                            scale: cell.current ? 1 : Theme.browser.badgeFrom

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastEffects
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: cell.current ? Theme.curve.emphasizedDecel : Theme.curve.emphasizedAccel
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "check"
                                size: Theme.icon.tiny
                                color: Theme.accentOn
                            }
                        }
                    }

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            leftMargin: Theme.spacing.small
                            rightMargin: Theme.spacing.small
                            bottomMargin: Theme.spacing.small
                        }

                        textFormat: Text.PlainText
                        text: Wallpapers.name(cell.modelData)
                        color: cell.current ? Theme.accentText : cell.hovered ? Theme.fg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        elide: Text.ElideRight

                        Behavior on color {
                            FastColor {}
                        }
                    }

                    MouseArea {
                        id: press

                        onPositionChanged: mouse => {
                            if (browser.pointerMoved(this, mouse.x, mouse.y) && browser.hoverPath !== cell.modelData) {
                                browser.hoverPath = cell.modelData;
                                previewDebounce.restart();
                            }
                        }

                        onClicked: cell.pick()

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (!hovered) {
                            previewDebounce.stop();
                            browser.hoverPath = "";
                            Wallpapers.clearPreview();
                        }
                    }
                }
            }

            Spinner {
                anchors.centerIn: grid
                visible: Wallpapers.scanning && Wallpapers.list.length === 0
                size: Theme.icon.huge
            }

            Text {
                anchors.centerIn: grid
                visible: !Wallpapers.scanning && browser.pictures.length === 0
                textFormat: Text.PlainText
                text: I18n.t("No wallpapers in ~/.wallpaper")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
            }
        }
    }

    Timer {
        id: previewDebounce

        onTriggered: {
            if (browser.hoverPath !== "")
                Wallpapers.preview(browser.hoverPath);
        }

        interval: Theme.duration.previewDebounce
    }
}
