pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Weather from wttr.in for the desktop widget, refreshed every half hour.
Singleton {
    id: root

    // Empty means wttr.in guesses from the IP address, which a VPN moves elsewhere.
    property string location: ""
    property var data: null

    readonly property bool ready: data !== null
    readonly property var now: data?.current_condition?.[0] ?? null
    readonly property var today: data?.weather?.[0] ?? null
    readonly property string area: location !== "" ? location : (data?.nearest_area?.[0]?.areaName?.[0]?.value ?? "")
    readonly property string temp: now?.temp_C ?? ""
    readonly property string condition: (now?.weatherDesc?.[0]?.value ?? "").trim()
    readonly property int code: Number(now?.weatherCode ?? 113)
    readonly property string high: today?.maxtempC ?? ""
    readonly property string low: today?.mintempC ?? ""

    // Now, then the next four 3-hourly forecasts, running into tomorrow.
    readonly property var hours: {
        if (!data)
            return [];
        const hour = new Date().getHours();
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
        if (!fetch.running)
            fetch.running = true;
    }

    function setLocation(place: string): void {
        location = place.trim();
        locationFile.setText(location);
        refresh();
    }

    Process {
        id: fetch
        command: ["curl", "-sf", "--max-time", "15", "https://wttr.in/" + encodeURIComponent(root.location) + "?format=j1"]
        stdout: StdioCollector {
            // A failed fetch keeps the last forecast rather than blanking the widget.
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                } catch (e) {}
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
        onLoadFailed: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        interval: Theme.duration.weatherRefresh
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "weather"

        // A place name wttr.in understands ("Hong Kong"); an empty string goes back to the IP guess.
        function setLocation(place: string): void {
            root.setLocation(place);
        }

        function refresh(): void {
            root.refresh();
        }
    }
}
