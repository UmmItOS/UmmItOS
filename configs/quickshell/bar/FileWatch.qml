import QtQuick
import ".."

// The latest file change: + new, ~ changed, − deleted, → moved. Fades when quiet.
Text {
    id: root

    readonly property var entry: FileChanges.last

    textFormat: Text.PlainText
    text: entry ? entry.glyph + " " + entry.path.slice(entry.path.lastIndexOf("/") + 1) : ""
    color: Theme.dim
    elide: Text.ElideMiddle
    font.family: Theme.font
    font.pixelSize: Theme.fontSize.smaller
    opacity: FileChanges.recent && Settings.watchShow ? 1 : 0
    visible: opacity > 0
    width: Math.min(implicitWidth, Theme.bar.fileWatch)

    Behavior on opacity {
        FastFade {}
    }
}
