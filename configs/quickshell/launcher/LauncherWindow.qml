pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import ".."

// Full-bleed grid rather than a centred panel: at this size the icons do the
// identifying, so the apps are the content and the chrome is one query line.
// Tiles are bare — only the focused one takes a surface, so the grid reads as
// content instead of a wall of buttons.
OverlayWindow {
    id: win

    shown: Launcher.open && Launcher.mode === "apps"
    name: "launcher"
    scrim: 0.78

    property string filter: ""

    readonly property int total: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).length

    // Ranked, not alphabetical. With no query the apps you open most come
    // first. With one, a match at the start of the name beats one at the start
    // of a later word, which beats one anywhere in the name, which beats a
    // keyword; use breaks ties, then the alphabet.
    // The use counts as they were on opening: a launch counts itself while the
    // grid fades out, and ranking live re-sorted the tiles under the fade.
    property var used: ({})

    readonly property var results: {
        const f = filter.toLowerCase();
        const used = win.used;
        const rank = a => {
            if (f === "")
                return 0;
            const name = a.name.toLowerCase();
            if (name.startsWith(f))
                return 0;
            if (name.includes(" " + f))
                return 1;
            if (name.includes(f))
                return 2;
            // keywords and categories are lists, not strings: calling
            // toLowerCase() on one throws and empties the whole binding.
            return [a.genericName ?? "", ...(a.keywords ?? [])].join(" ").toLowerCase().includes(f) ? 3 : -1;
        };
        return [...DesktopEntries.applications.values].filter(a => !a.noDisplay).map(a => ({
                    app: a,
                    rank: rank(a),
                    used: used[a.id] ?? 0
                })).filter(r => r.rank >= 0).sort((x, y) => (x.rank - y.rank) || (y.used - x.used) || x.app.name.localeCompare(y.app.name)).map(r => r.app);
    }

    onOpened: {
        used = Launcher.launches;
        filter = "";
        search.text = "";
        grid.currentIndex = 0;
        search.forceActiveFocus();
    }

    function accept(): void {
        const item = results[grid.currentIndex];
        if (item)
            Launcher.launch(item);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.open = false
    }

    FocusScope {
        anchors.fill: parent
        focus: true
        opacity: Math.min(1, win.reveal)
        scale: Theme.popScale + (1 - Theme.popScale) * win.reveal

        // The query line. Oversized and left-anchored, so the eye starts at the
        // same place whether you are typing or scanning.
        ColumnLayout {
            id: head

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: Theme.padding.extraLarge * 2
                leftMargin: Theme.padding.extraLarge * 3
                rightMargin: Theme.padding.extraLarge * 3
            }
            spacing: Theme.spacing.small

            TextInput {
                id: search

                Layout.fillWidth: true
                color: Theme.fg
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSize.query
                font.weight: Theme.weight.bold
                focus: true

                onTextChanged: {
                    win.filter = text;
                    grid.currentIndex = 0;
                }

                Keys.onEscapePressed: Launcher.open = false
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onReturnPressed: win.accept()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: search.text === ""
                    text: "Search " + win.total + " apps"
                    color: Theme.dim
                    font: search.font
                }
            }

            // Only while typing: the placeholder already says how many there
            // are, so this is the answer to the query, not a second header.
            Text {
                Layout.topMargin: Theme.spacing.extraSmall
                opacity: search.text === "" ? 0 : 1
                text: win.results.length === 0 ? "Nothing matches" : win.results.length === 1 ? "1 match, Enter to open" : win.results.length + " matches, Enter opens the first"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
                font.weight: Theme.weight.medium
                font.letterSpacing: Theme.tracking.wide
            }
        }

        GridView {
            id: grid

            anchors {
                top: head.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: Theme.padding.extraLarge * 2
                leftMargin: Theme.padding.extraLarge * 3 - Theme.spacing.medium
                rightMargin: Theme.padding.extraLarge * 3 - Theme.spacing.medium
                bottomMargin: Theme.padding.extraLarge
            }
            clip: true
            cellWidth: Math.floor(width / Math.max(4, Math.floor(width / 190)))
            cellHeight: 168
            model: win.results
            currentIndex: 0
            // Keep the focused tile in view when arrowing past the fold.
            highlightMoveDuration: Theme.duration.expressiveFastEffects
            highlightRangeMode: GridView.ApplyRange
            preferredHighlightBegin: cellHeight
            preferredHighlightEnd: height - cellHeight * 2

            delegate: Item {
                id: cell
                required property DesktopEntry modelData
                required property int index

                readonly property bool active: GridView.isCurrentItem

                width: grid.cellWidth
                height: grid.cellHeight

                Surface {
                    anchors {
                        fill: parent
                        margins: Theme.spacing.medium
                    }
                    radius: Theme.rounding.extraLarge
                    tone: Theme.bgTray
                    opacity: cell.active ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.duration.expressiveFastEffects
                        }
                    }

                    layer.enabled: cell.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.accent
                        shadowBlur: 1
                        shadowOpacity: 0.5
                        shadowVerticalOffset: 0
                        shadowHorizontalOffset: 0
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - Theme.spacing.extraLargeIncreased
                    spacing: Theme.spacing.medium

                    IconImage {
                        id: appIcon
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: Theme.icon.app
                        visible: status === Image.Ready
                        source: Quickshell.iconPath(cell.modelData.icon, true)
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !appIcon.visible
                        text: "widgets"
                        color: Theme.dim
                        size: Theme.icon.app
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        color: cell.active ? Theme.fg : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.smaller
                        font.weight: cell.active ? Theme.weight.medium : Theme.weight.regular
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }

                scale: cell.active ? 1.04 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.duration.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        if (win.pointerMoved(this, mouse.x, mouse.y))
                            grid.currentIndex = cell.index;
                    }
                    onClicked: win.accept()
                }
            }
        }
    }
}
