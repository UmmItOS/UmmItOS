import QtQuick

// A list's last row while a scan may still add more.
Item {
    id: root

    property bool searching: false
    property string text

    implicitHeight: root.searching ? Theme.control.row : 0
    visible: root.searching

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacing.medium

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.smaller
            }
        }
    }
}
