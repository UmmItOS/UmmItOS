pragma ComponentBehavior: Bound

import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

OverlayWindow {
    id: win

    function accept(): void {
        const shot = Gallery.shots[grid.currentIndex];
        if (shot)
            Gallery.copy(shot.path);
    }

    onOpened: {
        grid.currentIndex = 0;
        scope.forceActiveFocus();
    }

    shown: Gallery.open
    name: "gallery"
    scrim: Theme.shade.heavy

    MouseArea {
        onClicked: Gallery.open = false

        anchors.fill: parent
    }

    FocusScope {
        id: scope

        Keys.onEscapePressed: Gallery.open = false
        Keys.onLeftPressed: grid.moveCurrentIndexLeft()
        Keys.onRightPressed: grid.moveCurrentIndexRight()
        Keys.onUpPressed: grid.moveCurrentIndexUp()
        Keys.onDownPressed: grid.moveCurrentIndexDown()
        Keys.onReturnPressed: win.accept()
        Keys.onEnterPressed: win.accept()

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
                text: I18n.t("%1 screenshots in %2").arg(Gallery.shots.length).arg(Settings.tilde(Screenshot.dir))
                color: Theme.dim
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
                opacity: Gallery.loading ? 0 : 1
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
            cellWidth: Math.floor(width / Math.max(Theme.gallery.minColumns, Math.floor(width / Theme.gallery.cellMin)))
            cellHeight: Math.round(cellWidth * Theme.gallery.ratio) + Theme.gallery.label
            model: Gallery.shots
            currentIndex: 0
            highlightMoveDuration: Theme.duration.expressiveFastEffects
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: cellHeight
            preferredHighlightEnd: height - cellHeight * 2

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property bool active: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight
                scale: cell.active ? Theme.gallery.activeScale : 1

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

                        Image {
                            anchors.fill: parent
                            source: "file://" + cell.modelData.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: grid.cellWidth * 2
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                FastFade {}
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacing.small

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: cell.modelData.name
                            color: cell.active ? Theme.fg : Theme.dim
                            elide: Text.ElideMiddle
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.smaller
                            font.weight: cell.active ? Theme.weight.medium : Theme.weight.regular
                        }

                        Text {
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

        FlyoutEmpty {
            anchors.fill: grid
            visible: !Gallery.loading && Gallery.shots.length === 0
            icon: "screenshot_region"
            text: I18n.t("No screenshots yet")
        }

        Text {
            id: foot

            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: Theme.spacing.extraLarge
            }

            text: I18n.t("Enter to copy · Esc to close")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            opacity: Gallery.shots.length > 0 ? 1 : 0
        }
    }
}
