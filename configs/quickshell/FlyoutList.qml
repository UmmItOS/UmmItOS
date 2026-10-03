import Quickshell
import QtQuick
import QtQuick.Layouts

// A flyout's scrolling device list: rows diff in place and the view stays on top while the list reorders.
ListView {
    id: list

    property var values: []
    property bool searching: false
    property string searchText

    // Rows moving to the top (the connected one) otherwise scroll it out of view.
    property bool atTop: true

    onMovementEnded: atTop = atYBeginning
    onVisibleChanged: atTop = true

    onValuesChanged: {
        if (atTop)
            Qt.callLater(positionViewAtBeginning);
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    spacing: Theme.spacing.extraSmall
    boundsBehavior: Flickable.StopAtBounds

    // ScriptModel diffs, so surviving rows are kept, not rebuilt.
    model: ScriptModel {
        values: list.values
    }

    // Discovery takes seconds; until then only known entries show.
    footer: FlyoutSearching {
        width: list.width
        searching: list.searching
        text: list.searchText
    }
}
