import QtQuick
import QtQuick.Layouts
import ".."

// Where the desktop weather is for; shows the current sky once a place is set.
BarButton {
    id: root

    property bool popupOpen: false

    icon: Weather.ready ? Weather.icon(Weather.code, Weather.hour) : "add_location_alt"
    label: "Weather"
    onClicked: popupOpen = !popupOpen

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: I18n.t("Weather")
        busy: Weather.location !== "" && !Weather.ready && !Weather.failed
        toggleVisible: false
        hug: true
        onCloseRequested: root.popupOpen = false
        // Typing breaks the text binding, so each opening starts from the saved place.
        onVisibleChanged: {
            if (visible) {
                field.text = Weather.location;
                field.forceActiveFocus();
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.control.field
            radius: Theme.rounding.full
            color: Theme.bgAlt

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.medium
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

                    Connections {
                        target: Weather
                        function onLocationChanged(): void {
                            field.text = Weather.location;
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === ""
                        text: I18n.t("City or district")
                        color: Theme.dim
                        font: field.font
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: {
                if (Weather.location === "")
                    return I18n.t("Type a place, then Enter. The weather shows once it is set.");
                if (Weather.failed)
                    return I18n.t("wttr.in does not know \"%1\". Try another name.").arg(Weather.location);
                if (!Weather.ready)
                    return I18n.t("Looking up %1…").arg(Weather.location);
                return I18n.t("Matched %1: %2°, %3. Empty and Enter turns it off.").arg(Weather.matched).arg(Weather.temp).arg(Weather.condition.toLowerCase());
            }
            color: Weather.failed ? Theme.urgent : Theme.dim
            font {
                family: Theme.font
                pixelSize: Theme.fontSize.small
            }
        }
    }
}
