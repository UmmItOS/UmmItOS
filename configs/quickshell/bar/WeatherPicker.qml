import QtQuick
import QtQuick.Layouts
import ".."

// Where the desktop weather is for; shows the current sky once a place is set.
BarButton {
    id: root

    property bool popupOpen: false

    icon: Weather.ready ? Weather.icon(Weather.code, new Date().getHours()) : "add_location_alt"
    onClicked: popupOpen = !popupOpen

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: "Weather"
        busy: Weather.location !== "" && !Weather.ready && !Weather.failed
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.control.field
            radius: Theme.rounding.full
            color: Theme.bgAlt

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.padding.large
                    rightMargin: Theme.padding.medium
                }
                spacing: Theme.spacing.small

                MaterialIcon {
                    text: "location_on"
                    color: Theme.dim
                    size: Theme.icon.small
                }

                TextInput {
                    id: field

                    Layout.fillWidth: true
                    text: Weather.location
                    color: Theme.fg
                    selectByMouse: true
                    clip: true
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.smaller
                    }
                    Keys.onReturnPressed: Weather.setLocation(text)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === ""
                        text: "City or district"
                        color: Theme.dim
                        font: field.font
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: {
                if (Weather.location === "")
                    return "Type a place, then Enter. The weather shows once it is set.";
                if (Weather.failed)
                    return "wttr.in does not know \"" + Weather.location + "\". Try another name.";
                if (!Weather.ready)
                    return "Looking up " + Weather.location + "…";
                return "Matched " + Weather.matched + ": " + Weather.temp + "°, " + Weather.condition.toLowerCase() + ". Empty and Enter turns it off.";
            }
            color: Weather.failed ? Theme.urgent : Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
            }
        }
    }
}
