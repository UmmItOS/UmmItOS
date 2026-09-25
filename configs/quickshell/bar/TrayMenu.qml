pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import ".."

// Drawn by the shell: Qt's own menus follow the light platform theme.
Flyout {
    id: root

    required property QsMenuHandle menu

    // Submenus entered, innermost last.
    property var trail: []

    signal done

    implicitWidth: Theme.control.menu
    hug: true
    toggleVisible: false

    onVisibleChanged: {
        if (!visible)
            trail = [];
    }

    QsMenuOpener {
        id: opener
        // Only while open: an opener keeps the D-Bus menu live.
        menu: !root.visible ? null : root.trail.length > 0 ? root.trail[root.trail.length - 1] : root.menu
    }

    // Scrolls once the menu is taller than the screen allows.
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: rows.implicitHeight
        contentHeight: rows.implicitHeight
        interactive: contentHeight > height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: rows

            width: parent.width
            // The same gap the flyout body puts between rows.
            spacing: Theme.spacing.medium

            FlyoutRow {
                Layout.fillWidth: true
                visible: root.trail.length > 0

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.padding.medium
                        rightMargin: Theme.padding.medium
                    }
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: "chevron_left"
                        color: Theme.dim
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Back"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.normal
                    }
                }

                TapHandler {
                    onTapped: root.trail = root.trail.slice(0, -1)
                }
            }

            Repeater {
                model: opener.children

                Item {
                    id: item

                    required property QsMenuEntry modelData

                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? Theme.spacing.medium : Theme.control.row

                    // A divider, not a border: the gap between two groups of rows.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - Theme.padding.medium * 2
                        height: 1
                        color: Theme.bgTray
                        visible: item.modelData.isSeparator
                    }

                    FlyoutRow {
                        anchors.fill: parent
                        visible: !item.modelData.isSeparator
                        color: hovered && item.modelData.enabled ? Theme.bgTray : "transparent"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Theme.padding.medium
                                rightMargin: Theme.padding.medium
                            }
                            spacing: Theme.spacing.medium

                            MaterialIcon {
                                visible: item.modelData.buttonType !== QsMenuButtonType.None
                                text: {
                                    const on = item.modelData.checkState === Qt.Checked;
                                    if (item.modelData.buttonType === QsMenuButtonType.RadioButton)
                                        return on ? "radio_button_checked" : "radio_button_unchecked";
                                    return on ? "check_box" : "check_box_outline_blank";
                                }
                                color: item.modelData.checkState === Qt.Checked ? Theme.accentText : Theme.dim
                                fill: item.modelData.checkState === Qt.Checked ? 1 : 0
                            }

                            IconImage {
                                // A missing theme icon loads as a checkerboard, not an error.
                                readonly property var themed: item.modelData.icon.match(/^image:\/\/icon\/([^/].*)$/)

                                visible: item.modelData.buttonType === QsMenuButtonType.None && item.modelData.icon !== "" && status === Image.Ready && (!themed || Quickshell.iconPath(themed[1], true) !== "")
                                implicitSize: Theme.icon.small
                                source: item.modelData.icon
                            }

                            Text {
                                Layout.fillWidth: true
                                // dbusmenu marks keyboard accelerators with an underscore.
                                text: item.modelData.text.replace(/_([^_])/g, "$1")
                                color: item.modelData.enabled ? Theme.fg : Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.normal
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                visible: item.modelData.hasChildren
                                text: "chevron_right"
                                color: Theme.dim
                            }
                        }

                        TapHandler {
                            enabled: item.modelData.enabled
                            onTapped: {
                                if (item.modelData.hasChildren) {
                                    root.trail = root.trail.concat([item.modelData]);
                                } else {
                                    item.modelData.triggered();
                                    root.done();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
