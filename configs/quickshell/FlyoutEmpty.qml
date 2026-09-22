import QtQuick
import QtQuick.Layouts

// What a flyout list shows with nothing to list: a glyph, or a spinner while
// it is still looking, and a line saying which empty case this is.
Item {
    id: root

    property string icon
    property string text
    property bool searching: false

    Layout.fillWidth: true
    Layout.fillHeight: true

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spacing.medium

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.searching
            text: root.icon
            color: Theme.dim
            size: Theme.icon.large
        }

        Spinner {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.searching
            size: Theme.icon.large
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.normal
            }
        }
    }
}
