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
        const base = Wallpapers.dir + "/" + browser.here;
        const all = browser.here === "" ? Wallpapers.list : Wallpapers.list.filter(p => p.slice(0, p.lastIndexOf("/")) === base);
        return [...all].sort((a, b) => a.localeCompare(b, undefined, {
                numeric: true
            }));
    }
    readonly property var rail: [
        {
            path: "",
            name: I18n.t("All"),
            depth: 0,
            count: Wallpapers.list.length
        }
    ].concat(Wallpapers.folders)

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

            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
                topMargin: Theme.barHeight
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
                    readonly property bool here: Wallpapers.folder === browser.here

                    onClicked: {
                        if (!here)
                            Wallpapers.setFolder(browser.here);
                    }

                    icon: "shuffle"
                    label: here ? "Shuffling from here" : "Shuffle from here"
                    baseColor: here ? Theme.dim : Theme.accentText
                    hoverColor: here ? Theme.dim : Theme.accent2
                }

                BarButton {
                    onClicked: Wallpapers.setRandom()

                    icon: "casino"
                    label: "Random"
                }

                BarButton {
                    onClicked: Wallpapers.browserOpen = false

                    icon: "close"
                    label: "Close"
                }
            }

            Flow {
                id: chips

                anchors {
                    left: parent.left
                    right: parent.right
                    top: bar.bottom
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                    topMargin: Theme.spacing.medium
                }

                spacing: Theme.spacing.small

                Repeater {
                    model: browser.rail

                    delegate: Rectangle {
                        id: chip

                        required property var modelData

                        readonly property bool active: browser.here === chip.modelData.path

                        Accessible.role: Accessible.RadioButton
                        Accessible.name: I18n.t("%1, %2 pictures").arg(chip.modelData.name).arg(chip.modelData.count)
                        Accessible.checkable: true
                        Accessible.checked: chip.active
                        Accessible.onPressAction: browser.here = chip.modelData.path
                        implicitWidth: label.implicitWidth + Theme.spacing.medium * 2
                        implicitHeight: label.implicitHeight + Theme.spacing.small * 2
                        radius: Theme.rounding.full
                        color: chip.active ? Theme.accent : chipHover.hovered ? Theme.glass : Theme.bgTray
                        scale: chipTap.pressed ? Theme.pressScale : 1

                        Behavior on color {
                            FastColor {}
                        }

                        Behavior on scale {
                            PressAnim {}
                        }

                        Text {
                            id: label

                            anchors.centerIn: parent
                            textFormat: Text.PlainText
                            text: chip.modelData.name
                            color: chip.active ? Theme.accentOn : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            font.weight: Theme.weight.medium
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: chipTap

                            onTapped: browser.here = chip.modelData.path
                        }
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

                    Accessible.role: Accessible.Button
                    Accessible.name: Wallpapers.name(cell.modelData)
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
                                left: parent.left
                                bottom: parent.bottom
                                margins: Theme.spacing.medium
                            }

                            visible: cell.modelData === Wallpapers.actual
                            implicitWidth: Theme.picker.dot
                            implicitHeight: Theme.picker.dot
                            radius: Theme.picker.dot / 2
                            color: Theme.accent
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
                        color: cell.hovered ? Theme.fg : Theme.dim
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
