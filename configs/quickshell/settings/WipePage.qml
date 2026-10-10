pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: page

    // What is ticked to be wiped, and how many times it is overwritten.
    property var picks: ({
            ocr: true,
            clipboard: true,
            changes: true,
            launches: true,
            place: true,
            temp: true
        })
    property int passes: 3

    readonly property var kinds: [
        {
            key: "ocr",
            title: I18n.t("Screenshot text"),
            hint: I18n.t("The words read out of your screenshots, for the gallery search."),
            by: I18n.t("Written by script/misc/ocr-index.sh (tesseract), when the gallery opens and when a screenshot is saved.")
        },
        {
            key: "clipboard",
            title: I18n.t("Clipboard"),
            hint: I18n.t("Copy history, picture previews and what is on the clipboard now."),
            by: I18n.t("Written by cliphist through script/cliphist/clip-store.sh on every copy; previews by the clipboard window.")
        },
        {
            key: "changes",
            title: I18n.t("File change history"),
            hint: I18n.t("The list behind the bar's history button."),
            by: I18n.t("Kept by the shell (bar/FileChanges.qml) in its state folder.")
        },
        {
            key: "launches",
            title: I18n.t("App launch counts"),
            hint: I18n.t("What the launcher ranks apps by."),
            by: I18n.t("Kept by the launcher (launcher/Launcher.qml) in the shell's state folder.")
        },
        {
            key: "place",
            title: I18n.t("Weather place"),
            hint: I18n.t("The place you typed for the weather."),
            by: I18n.t("Kept by the weather service (services/Weather.qml) in the shell's state folder.")
        },
        {
            key: "temp",
            title: I18n.t("Temporary pictures"),
            hint: I18n.t("Frozen screens the lock, scan and screenshot tools leave in the runtime folder."),
            by: I18n.t("Made by the shell in the runtime folder (memory-backed, gone at reboot).")
        }
    ]

    readonly property var chosen: kinds.filter(k => picks[k.key]).map(k => k.key)

    // File systems that write a changed block somewhere new, so the old one lives on.
    readonly property bool copyOnWrite: ["btrfs", "zfs", "f2fs", "bcachefs", "nilfs2"].includes(Settings.traceFs)

    function pick(key: string, on: bool): void {
        const next = Object.assign({}, picks);
        next[key] = on;
        picks = next;
    }

    function total(files: var): int {
        return files.reduce((sum, f) => sum + f.bytes, 0);
    }

    Component.onCompleted: Settings.scanTraces()

    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Anti-forensics")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Overwrites, then deletes, what the desktop remembers, so it cannot be read back from the files.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    Flickable {
        id: scroll

        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            background: null

            contentItem: Rectangle {
                implicitWidth: Theme.spacing.extraSmall
                radius: width / 2
                color: Theme.dim
            }
        }

        ColumnLayout {
            id: list

            width: scroll.width - Theme.spacing.large
            spacing: Theme.spacing.medium

            SettingRow {
                title: I18n.t("Search text in screenshots")
                hint: I18n.t("Reads the text inside each new screenshot so the gallery can search it. Off reads nothing more.")

                Toggle {
                    onToggled: Settings.setOcr(!Settings.ocrEnabled)

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Settings.ocrEnabled
                }
            }

            Repeater {
                model: page.kinds

                Rectangle {
                    id: card

                    required property var modelData
                    readonly property var files: Settings.traces[modelData.key] ?? []
                    readonly property int shown: 3

                    Layout.fillWidth: true
                    implicitHeight: inner.implicitHeight + Theme.spacing.large * 2
                    radius: Theme.rounding.large
                    color: Theme.bgAlt

                    ColumnLayout {
                        id: inner

                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: Theme.spacing.large
                        }

                        spacing: Theme.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacing.large

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    textFormat: Text.PlainText
                                    text: card.modelData.title
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.normal
                                    font.weight: Theme.weight.medium
                                }

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.PlainText
                                    text: card.modelData.hint
                                    wrapMode: Text.Wrap
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.small
                                }
                            }

                            Toggle {
                                onToggled: page.pick(card.modelData.key, !page.picks[card.modelData.key])

                                checked: page.picks[card.modelData.key] ?? false
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.spacing.extraSmall
                            textFormat: Text.PlainText
                            text: card.modelData.by
                            wrapMode: Text.Wrap
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }

                        Repeater {
                            model: card.files.slice(0, card.shown)

                            RowLayout {
                                id: fileRow

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Theme.spacing.medium

                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.PlainText
                                    text: Settings.tilde(fileRow.modelData.path)
                                    elide: Text.ElideMiddle
                                    color: Theme.accentText
                                    font.family: "monospace"
                                    font.pixelSize: Theme.fontSize.small
                                }

                                Text {
                                    textFormat: Text.PlainText
                                    text: Settings.size(fileRow.modelData.bytes)
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize.small

                                    font.features: ({
                                            tnum: 1
                                        })
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            textFormat: Text.PlainText
                            text: card.files.length === 0 ? I18n.t("Nothing stored") : card.files.length > card.shown ? I18n.t("+%1 more · %2 in all").arg(card.files.length - card.shown).arg(Settings.size(page.total(card.files))) : card.files.length > 1 ? I18n.t("%1 in all").arg(Settings.size(page.total(card.files))) : ""
                            visible: text !== ""
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.small
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: limits.implicitHeight + Theme.spacing.large * 2
                radius: Theme.rounding.large
                color: Theme.glass

                RowLayout {
                    id: limits

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: Theme.spacing.large
                    }

                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: "warning"
                        color: Theme.warn
                        size: Theme.icon.normal
                        fill: 1
                    }

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: page.copyOnWrite ? I18n.t("Overwriting cannot reach everything. Your files sit on %1, which keeps old copies when it overwrites. Encrypt the disk if that matters.").arg(Settings.traceFs) : I18n.t("Overwriting cannot reach everything. An SSD can keep old data in blocks it hides, and backups are not touched. Encrypt the disk if that matters.")
                        wrapMode: Text.Wrap
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize.small
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing.large

        Text {
            text: I18n.t("Overwrite passes")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }

        Segmented {
            onPicked: value => page.passes = value

            Layout.preferredWidth: Theme.settings.choice / 2
            values: [1, 3, 7]
            labels: ["1", "3", "7"]
            current: page.passes
            enabled: !Settings.wiping
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.medium

            Spinner {
                visible: Settings.wiping
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: Settings.wipeResult
                elide: Text.ElideRight
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.small
            }
        }

        ConfirmButton {
            onConfirmed: Settings.wipe(page.chosen, page.passes)

            icon: "delete_forever"
            label: I18n.t("Wipe the selected traces")
            hint: I18n.t("Wipe for good?")
            enabled: !Settings.wiping && page.chosen.length > 0
            opacity: enabled ? 1 : Theme.disabledOpacity
        }
    }
}
