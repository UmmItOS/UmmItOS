pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

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
    readonly property string hereName: browser.here === "" ? I18n.t("All") : browser.here.slice(browser.here.lastIndexOf("/") + 1)

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
    scrim: Theme.browser.scrim

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

            anchors.centerIn: parent
            width: Math.round(browser.width * Theme.browser.share)
            height: Math.round(browser.height * Theme.browser.share)
            radius: Theme.rounding.extraLarge
            opacity: Math.min(1, browser.reveal)
            scale: Theme.popScale + (1 - Theme.popScale) * browser.reveal

            // Swallows clicks, so only the empty desktop around the panel closes it.
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
                    textFormat: Text.PlainText
                    text: I18n.t("Wallpapers")
                    color: Theme.fg
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSize.extraLarge
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: browser.hereName
                    color: Theme.accentText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize.normal
                    font.weight: Theme.weight.medium
                    elide: Text.ElideRight
                }

                Action {
                    onClicked: Wallpapers.setFolder(browser.here)

                    primary: true
                    icon: "shuffle"
                    label: Wallpapers.folder === browser.here ? I18n.t("Shuffling from here") : I18n.t("Shuffle from here")
                    enabled: Wallpapers.folder !== browser.here
                }

                Action {
                    onClicked: Wallpapers.setRandom()

                    icon: "casino"
                    label: I18n.t("Random")
                }
            }

            ListView {
                id: rail

                anchors {
                    left: parent.left
                    top: bar.bottom
                    bottom: parent.bottom
                    margins: Theme.spacing.large
                }

                width: Theme.browser.railWidth
                clip: true
                spacing: Theme.spacing.extraSmall
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: browser.rail
                }

                delegate: FlyoutRow {
                    id: row

                    required property var modelData

                    Accessible.role: Accessible.RadioButton
                    Accessible.name: I18n.t("%1, %2 pictures").arg(row.modelData.name).arg(row.modelData.count)
                    Accessible.checkable: true
                    Accessible.checked: row.active
                    width: ListView.view.width
                    active: browser.here === row.modelData.path
                    scale: tap.pressed ? Theme.pressScale : 1

                    Behavior on scale {
                        PressAnim {}
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: Theme.spacing.medium + row.modelData.depth * Theme.browser.indent
                            rightMargin: Theme.spacing.medium
                        }

                        spacing: Theme.spacing.small

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: row.modelData.name
                            color: row.ink
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
                            elide: Text.ElideRight
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: row.modelData.count
                            color: row.inkDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller

                            font.features: ({
                                    tnum: 1
                                })
                        }
                    }

                    TapHandler {
                        id: tap

                        onTapped: browser.here = row.modelData.path
                    }
                }
            }

            GridView {
                id: grid

                readonly property int columns: Math.max(1, Math.floor(width / Theme.browser.cellWidth))

                anchors {
                    left: rail.right
                    right: parent.right
                    top: bar.bottom
                    bottom: parent.bottom
                    margins: Theme.spacing.large
                }

                clip: true
                cellWidth: Math.floor(width / columns)
                cellHeight: Math.round(cellWidth * Theme.browser.cellHeight / Theme.browser.cellWidth)
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
                            fill: parent
                            margins: Theme.spacing.small
                        }

                        radius: Theme.rounding.large
                        color: Theme.bgTray
                        scale: press.pressed ? Theme.pressScale : cell.hovered ? Theme.browser.hoverScale : 1

                        Behavior on scale {
                            PressAnim {}
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: grid.cellWidth
                            sourceSize.height: grid.cellHeight
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
                            color: Theme.accentText
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
