import QtQuick
import QtQuick.Layouts
import ".."

// Small switches that belong to no other page.
ColumnLayout {
    id: page

    // The key field's last try was refused.
    property bool keyRejected: false

    spacing: Theme.spacing.large

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
            text: I18n.t("Misc")
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.larger
            font.weight: Theme.weight.bold
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("Small things that have no page of their own.")
            wrapMode: Text.Wrap
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.small
        }
    }

    SettingRow {
        title: I18n.t("Activate Linux")
        hint: I18n.t("A grey reminder in the corner of the screen, as another system has.")

        Toggle {
            onToggled: Settings.setActivate(!Settings.activateShow)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.activateShow
        }
    }

    SettingRow {
        title: I18n.t("Show FPS")
        hint: I18n.t("A frame-rate counter in the top-left corner, like cl_showfps 1.")

        Toggle {
            onToggled: Settings.setFps(!Settings.fpsShow)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.fpsShow
        }
    }

    SettingRow {
        title: I18n.t("Warn about heavy processes")
        hint: I18n.t("When one process keeps the CPU above %1% or the GPU above %2% for %3 seconds, the bar says so. It never kills anything.").arg(Theme.hog.cpu).arg(Theme.hog.gpu).arg(Theme.hog.samples * Theme.duration.hogPoll / 1000)

        Toggle {
            onToggled: Settings.setHogWarn(!Settings.hogWarn)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.hogWarn
        }
    }

    SettingRow {
        title: I18n.t("DeepSeek balance")
        hint: I18n.t("A card on the desktop with what is left on your DeepSeek account. It needs the key below.")

        Toggle {
            onToggled: Settings.setDeepseekCard(!Settings.deepseekShow)

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Settings.deepseekShow
        }
    }

    SettingRow {
        title: I18n.t("DeepSeek API key")
        hint: page.keyRejected ? I18n.t("That does not look like a key.") : DeepSeek.keySaved ? I18n.t("A key is saved. Paste a new one and press Enter to replace it.") : I18n.t("Paste your key, then press Enter. It stays in ~/.config/ummitos/deepseek.key, for you only.")
        warn: page.keyRejected

        Rectangle {
            anchors.fill: parent
            radius: Theme.rounding.full
            color: Theme.bgTray

            TextInput {
                id: keyField

                function save(): void {
                    page.keyRejected = !DeepSeek.setKey(text);
                    if (!page.keyRejected)
                        text = "";
                }

                Keys.onReturnPressed: save()
                Keys.onEnterPressed: save()
                onTextEdited: page.keyRejected = false

                anchors {
                    fill: parent
                    leftMargin: Theme.spacing.large
                    rightMargin: Theme.spacing.large
                }

                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.fg
                selectByMouse: true
                clip: true
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.smaller
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: DeepSeek.keySaved

        Item {
            Layout.fillWidth: true
        }

        Action {
            onClicked: DeepSeek.clearKey()

            icon: "delete"
            label: I18n.t("Remove the key")
        }
    }

    SettingRow {
        title: I18n.t("Read the balance every")
        hint: I18n.t("How often the card asks DeepSeek again while it shows.")

        Segmented {
            onPicked: value => Settings.setDeepseekSeconds(value)

            anchors.fill: parent
            values: [15, 30, 60, 300, 600]
            labels: [I18n.t("%1 s").arg(15), I18n.t("%1 s").arg(30), I18n.t("%1 min").arg(1), I18n.t("%1 min").arg(5), I18n.t("%1 min").arg(10)]
            current: Settings.deepseekSeconds
        }
    }

    SettingRow {
        title: I18n.t("Balance currency")
        hint: I18n.t("DeepSeek reports each currency the account holds. This picks which one the card shows; nothing is converted.")

        Segmented {
            onPicked: value => Settings.setDeepseekCurrency(value)

            anchors.fill: parent
            values: ["CNY", "USD"]
            labels: ["CNY ¥", "USD $"]
            current: Settings.deepseekCurrency
        }
    }

    Item {
        Layout.fillHeight: true
    }
}
