pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// The DeepSeek account balance: what is left, and what it is made of.
Rectangle {
    id: card

    readonly property bool wanted: Settings.deepseekShow
    // Said in place of the balance when there is none to show, or under it when it is not good.
    readonly property string note: DeepSeek.noKey ? I18n.t("Add your DeepSeek API key in Settings, Misc.") : DeepSeek.failed ? I18n.t("Can't read the balance. Check the key.") : DeepSeek.ready && !DeepSeek.usable ? I18n.t("Balance too low for API calls") : DeepSeek.otherCurrency ? I18n.t("No %1 balance on this account.").arg(Settings.deepseekCurrency) : ""

    implicitWidth: Theme.widgetWidth
    implicitHeight: body.implicitHeight + Theme.spacing.large * 2
    radius: Theme.rounding.extraLarge
    color: Theme.scrim(Theme.panelTint)

    // Its window maps when the card has something to say, so this runs on each appearance.
    opacity: card.wanted && (DeepSeek.ready || card.note !== "") ? 1 : 0
    layer.enabled: opacity < 1

    layer.effect: MotionBlur {
        settled: card.opacity
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.expressiveDefaultEffects
        }
    }

    ColumnLayout {
        id: body

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spacing.large
        }

        spacing: Theme.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing.small

            MaterialIcon {
                text: "account_balance_wallet"
                color: Theme.accentText
                fill: 1
                size: Theme.icon.small
            }

            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: "DeepSeek"
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize.normal
                font.weight: Theme.weight.medium
            }
        }

        Text {
            visible: DeepSeek.ready
            textFormat: Text.PlainText
            text: DeepSeek.symbol + DeepSeek.total
            color: Theme.fg
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontSize.huge
            font.weight: Font.Light

            font.features: ({
                    tnum: 1
                })
        }

        Text {
            Layout.fillWidth: true
            visible: DeepSeek.ready
            textFormat: Text.PlainText
            text: I18n.t("Granted %1 · Topped up %2").arg(DeepSeek.granted).arg(DeepSeek.toppedUp)
            elide: Text.ElideRight
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }

        Text {
            Layout.fillWidth: true
            visible: card.note !== ""
            textFormat: Text.PlainText
            text: card.note
            wrapMode: Text.WordWrap
            color: Theme.warn
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
        }
    }
}
