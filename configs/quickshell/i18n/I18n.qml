pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The shell's language. Text reads I18n.t("English"); a binding re-runs when the words change.
Singleton {
    id: root

    property string lang: "en"
    readonly property var languages: [
        {
            code: "en",
            name: "English"
        },
        {
            code: "zh-HK",
            name: "廣東話"
        },
        {
            code: "zh-TW",
            name: "台灣華語"
        }
    ]
    // i18n/<lang>.json, keyed by the English text; empty for English.
    property var words: ({})
    // For dates and numbers written by Qt.
    readonly property var locale: lang === "en" ? Qt.locale() : Qt.locale(lang.replace("-", "_"))

    // A missing translation falls back to the English key.
    function t(text: string): string {
        return root.words[text] ?? text;
    }

    function set(code: string): void {
        lang = code;
        saved.setText(code + "\n");
    }

    FileView {
        id: saved

        path: Quickshell.statePath("language.txt")
        printErrors: false
        blockWrites: false
        onLoaded: {
            const code = text().trim();
            if (root.languages.some(l => l.code === code))
                root.lang = code;
        }
    }

    FileView {
        path: root.lang === "en" ? "" : Qt.resolvedUrl(root.lang + ".json").toString().replace("file://", "")
        // Loaded before first paint, so the desktop does not flash English at startup.
        blockLoading: true
        onLoaded: {
            try {
                root.words = JSON.parse(text());
            } catch (e) {
                console.warn("i18n: " + root.lang + ".json is not valid JSON: " + e);
                root.words = {};
            }
        }
        onLoadFailed: root.words = {}
        onPathChanged: if (path === "")
            root.words = {}
    }
}
