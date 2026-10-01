pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Weather from wttr.in for the desktop widget, refreshed every half hour.
Singleton {
    id: root

    // The place the user typed, shown under that name; no IP guess, which a VPN moves elsewhere.
    property string location: ""
    property var data: null
    property bool failed: false

    readonly property bool ready: data !== null
    // Ticks each hour, so day and night icons switch even when the sky stays the same.
    readonly property int hour: clock.date.getHours()
    readonly property var now: data?.current_condition?.[0] ?? null
    readonly property var today: data?.weather?.[0] ?? null
    // Where wttr.in matched the name, which may not be the place meant.
    readonly property string matched: [data?.nearest_area?.[0]?.areaName?.[0]?.value, data?.nearest_area?.[0]?.country?.[0]?.value].filter(v => v).join(", ")
    readonly property string temp: now?.temp_C ?? ""
    // wttr.in writes Traditional Chinese for zh-tw, which Hong Kong reads too.
    readonly property string wttrLang: I18n.lang === "en" ? "" : "zh-tw"
    readonly property string condition: (now?.["lang_" + wttrLang]?.[0]?.value ?? now?.weatherDesc?.[0]?.value ?? "").trim()
    readonly property int code: Number(now?.weatherCode ?? 113)
    readonly property string high: today?.maxtempC ?? ""
    readonly property string low: today?.mintempC ?? ""

    // Now, then the next four 3-hourly forecasts, running into tomorrow.
    readonly property var hours: {
        if (!data)
            return [];
        const hour = root.hour;
        const out = [{
                label: "Now",
                temp: temp,
                code: code,
                hour: hour
            }];
        for (let day = 0; day < 2 && out.length < 5; day++) {
            for (const h of data.weather?.[day]?.hourly ?? []) {
                const at = Number(h.time) / 100;
                if (day === 0 && at <= hour)
                    continue;
                out.push({
                    label: String(at).padStart(2, "0") + ":00",
                    temp: h.tempC,
                    code: Number(h.weatherCode),
                    hour: at
                });
                if (out.length === 5)
                    break;
            }
        }
        return out;
    }

    // WWO weather codes, as wttr.in reports them, to Material Symbols.
    function icon(code: int, hour: int): string {
        const night = hour < 6 || hour >= 18;
        if (code === 113)
            return night ? "clear_night" : "sunny";
        if (code === 116)
            return night ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 119 || code === 122)
            return "cloud";
        if ([143, 248, 260].includes(code))
            return "foggy";
        if ([200, 386, 389, 392, 395].includes(code))
            return "thunderstorm";
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(code))
            return "weather_snowy";
        return "rainy";
    }

    function refresh(): void {
        if (location === "" || fetch.running)
            return;
        fetch.place = location;
        fetch.lang = wttrLang;
        fetch.running = true;
    }

    // An empty place turns the weather off.
    function setLocation(place: string): void {
        location = place.trim();
        locationFile.setText(location);
        data = null;
        failed = false;
        refresh();
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Process {
        id: fetch

        // The place this fetch asked for; an answer for an older place is dropped.
        property string place
        // A language switch mid-fetch asks again once this one ends.
        property string lang

        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(place) + "?format=j1" + (lang !== "" ? "&lang=" + lang : "")]
        // 22 is wttr.in's HTTP error for an unknown place; any other failure (no network yet) is retried.
        onExited: code => {
            if (fetch.place !== root.location || fetch.lang !== root.wttrLang)
                Qt.callLater(root.refresh);
            else if (code === 22)
                root.failed = true;
            else if (code !== 0)
                retry.restart();
        }
        stdout: StdioCollector {
            // A failed fetch keeps the last forecast rather than blanking the widget.
            onStreamFinished: {
                if (fetch.place !== root.location || text.trim() === "")
                    return;
                try {
                    root.data = JSON.parse(text);
                    root.failed = false;
                } catch (e) {
                    root.failed = true;
                }
            }
        }
    }

    FileView {
        id: locationFile
        path: Quickshell.statePath("weather-location.txt")
        printErrors: false
        blockWrites: false
        onLoaded: {
            root.location = text().trim();
            root.refresh();
        }
    }

    // A new language needs the conditions written in it.
    Connections {
        target: I18n
        function onLangChanged(): void {
            root.refresh();
        }
    }

    // Timers stop while the laptop sleeps, so waking would show last night's forecast.
    Connections {
        target: Wake
        function onWoke(): void {
            root.refresh();
        }
    }

    Timer {
        id: retry
        interval: Theme.duration.weatherRetry
        onTriggered: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        interval: Theme.duration.weatherRefresh
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "weather"

        // A place name wttr.in understands ("Hong Kong"); an empty string turns the weather off.
        function setLocation(place: string): void {
            root.setLocation(place);
        }

        function refresh(): void {
            root.refresh();
        }
    }
}
