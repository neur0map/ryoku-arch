pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.dashboard.config
import qs.dashboard.modules.globals
import qs.services

Singleton {
    id: root

    // ─────────────────────────────────────────────────────────────
    // DATA SOURCE: ryoku's live `Weather` singleton (Open-Meteo)
    //
    // The visual/derived logic below (time blending, sun arc, weather
    // effects, etc.) is UNCHANGED — it just reads the raw props that
    // were historically filled by weather.sh. We now populate those raw
    // props from ryoku's `Weather` instead. The weather.sh Process and
    // its retry/cancel machinery are kept for API compatibility but are
    // never started.
    // ─────────────────────────────────────────────────────────────

    // Extract the "HH:MM" portion from ryoku's ISO "YYYY-MM-DD HH:MM[:SS]"
    function _timePortion(iso) {
        if (!iso)
            return "";
        var parts = iso.split(" ");
        if (parts.length < 2)
            return "";
        var hm = parts[1].split(":");
        return hm.length >= 2 ? (hm[0] + ":" + hm[1]) : parts[1];
    }

    // Re-populate the raw props from ryoku's Weather singleton.
    function syncFromRyoku() {
        var cc = Weather.cc;

        if (!cc) {
            root.dataAvailable = false;
            root.isLoading = (Weather.loc && Weather.loc.length > 0);
            return;
        }

        root.weatherCode = cc.weatherCode !== undefined ? parseInt(cc.weatherCode) : 0;
        root.currentTemp = convertTemp(cc.tempC !== undefined ? cc.tempC : 0);
        root.windSpeed = cc.windSpeed !== undefined ? cc.windSpeed : 0;
        root.isDay = cc.isDay === 1 || cc.isDay === true;

        var fc = Weather.forecast;
        if (fc && fc.length > 0) {
            root.maxTemp = convertTemp(fc[0].maxTempC !== undefined ? fc[0].maxTempC : 0);
            root.minTemp = convertTemp(fc[0].minTempC !== undefined ? fc[0].minTempC : 0);
        }

        // sunrise/sunset want "HH:MM"; ryoku cc.sunrise is "YYYY-MM-DD HH:MM"
        var sr = _timePortion(cc.sunrise);
        var ss = _timePortion(cc.sunset);
        if (sr.length > 0)
            root.sunrise = sr;
        if (ss.length > 0)
            root.sunset = ss;

        var forecastData = [];
        var dayCount = fc ? Math.min(7, fc.length) : 0;
        for (var i = 0; i < dayCount; i++) {
            var entry = fc[i];
            // ryoku stores date as "YYYY/MM/DD"
            var dateStr = (entry.date || "").replace(/\//g, "-");
            var dateParts = dateStr.split("-");
            var dayName = "Today";
            if (i !== 0 && dateParts.length === 3) {
                var year = parseInt(dateParts[0]);
                var month = parseInt(dateParts[1]) - 1;
                var day = parseInt(dateParts[2]);
                var dayDate = new Date(year, month, day);
                var rawDayName = dayDate.toLocaleDateString(Qt.locale(), "ddd");
                dayName = rawDayName.charAt(0).toUpperCase() + rawDayName.slice(1);
            }
            var code = entry.weatherCode !== undefined ? entry.weatherCode : 0;
            forecastData.push({
                date: dateStr,
                dayName: dayName,
                weatherCode: code,
                emoji: getWeatherCodeEmoji(code),
                maxTempC: entry.maxTempC,
                maxTempF: entry.maxTempF,
                minTempC: entry.minTempC,
                minTempF: entry.minTempF,
                maxTemp: convertTemp(entry.maxTempC),
                minTemp: convertTemp(entry.minTempC)
            });
        }
        root.forecast = forecastData;

        root.weatherSymbol = getWeatherCodeEmoji(root.weatherCode);
        root.weatherDescription = Weather.description;
        root.calculateSunPosition();
        root.dataAvailable = true;
        root.isLoading = false;
        root.hasFailed = false;
        root.retryCount = 0;
    }

    // Re-sync whenever ryoku's weather data changes.
    property var ryokuWeatherConnections: Connections {
        target: Weather
        function onCcChanged() {
            root.syncFromRyoku();
        }
        function onForecastChanged() {
            root.syncFromRyoku();
        }
    }

    property string weatherSymbol: ""
    property real currentTemp: 0
    property real maxTemp: 0
    property real minTemp: 0
    property int weatherCode: 0
    property real windSpeed: 0
    property bool dataAvailable: false
    property bool isLoading: false
    property bool hasFailed: false

    property var forecast: []

    property string sunrise: ""
    property string sunset: ""
    property real sunProgress: 0.0
    property bool isDay: true
    property string timeOfDay: "Day"
    property string weatherDescription: ""

    property bool debugMode: false
    property real debugHour: 12.0
    property int debugWeatherCode: 0

    readonly property string scriptPath: Quickshell.shellDir + "/dashboard/scripts/weather.sh"

    property int retryCount: 0
    readonly property int maxRetries: 3
    property bool wasCancelled: false

    property var suspendConnections: Connections {
        target: SuspendManager
        function onPreparingForSleep() {
            if (weatherProcess.running) {
                root.wasCancelled = true;
                weatherProcess.running = false;
            }
            if (retryTimer) retryTimer.stop();
        }
        function onWakingUp() {
            // Delay refresh on wake to allow network to stabilize
            if (wakeRefreshTimer) wakeRefreshTimer.restart();
        }
    }

    property var wakeRefreshTimer: Timer {
        id: wakeRefreshTimer
        interval: 5000
        repeat: false
        onTriggered: root.updateWeather()
    }

    property Timer refreshTimer: Timer {
        interval: 600000
        running: !SuspendManager.isSuspending
        repeat: true
        onTriggered: root.updateWeather()
    }

    property Timer sunPositionTimer: Timer {
        interval: 60000
        running: !SuspendManager.isSuspending && (GlobalStates.dashboardOpen || GlobalStates.launcherOpen || GlobalStates.overviewOpen)
        repeat: true
        onTriggered: root.calculateSunPosition()
    }

    property Timer retryTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: root.updateWeather()
    }

    function parseTime(timeStr) {
        if (!timeStr)
            return 0;
        var parts = timeStr.split(":");
        return parseInt(parts[0]) + parseInt(parts[1]) / 60;
    }

    readonly property real visualSunriseHour: 6.0
    readonly property real visualSunsetHour: 18.0

    // Calculate sun/moon progress based on hour (0-24 format)
    function calculateSunProgress(hour, sunriseH, sunsetH) {
        if (hour >= sunriseH && hour <= sunsetH) {
            return (hour - sunriseH) / (sunsetH - sunriseH);
        } else {
            var nightDuration = 24 - (sunsetH - sunriseH);
            if (hour > sunsetH) {
                return (hour - sunsetH) / nightDuration;
            } else {
                return (hour + (24 - sunsetH)) / nightDuration;
            }
        }
    }

    // Calculate debug values based on debugHour
    readonly property real debugSunProgress: calculateSunProgress(debugHour, visualSunriseHour, visualSunsetHour)
    readonly property bool debugIsDay: debugHour >= visualSunriseHour && debugHour <= visualSunsetHour

    function calculateTimeBlend(hour) {
        var day = 0, evening = 0, night = 0;

        if (hour >= 9 && hour <= 17) {
            day = 1.0;
        } else if (hour > 8 && hour < 9) {
            var t = hour - 8;
            evening = 1.0 - t;
            day = t;
        } else if (hour > 17 && hour < 18) {
            var t = hour - 17;
            day = 1.0 - t;
            evening = t;
        } else if (hour >= 6 && hour <= 8) {
            evening = 1.0;
        } else if (hour >= 18 && hour <= 20) {
            evening = 1.0;
        } else if (hour > 5 && hour < 6) {
            var t = hour - 5;
            night = 1.0 - t;
            evening = t;
        } else if (hour > 20 && hour < 21) {
            var t = hour - 20;
            evening = 1.0 - t;
            night = t;
        } else {
            night = 1.0;
        }

        return {
            day: day,
            evening: evening,
            night: night
        };
    }

    readonly property var debugTimeBlend: calculateTimeBlend(debugHour)
    property real currentHour: 12.0
    readonly property var realTimeBlend: calculateTimeBlend(currentHour)
    readonly property real realSunProgress: calculateSunProgress(currentHour, visualSunriseHour, visualSunsetHour)
    readonly property real realSunriseHour: sunrise.length > 0 ? parseTime(sunrise) : 6.0
    readonly property real realSunsetHour: sunset.length > 0 ? parseTime(sunset) : 18.0
    readonly property bool realIsDay: currentHour >= realSunriseHour && currentHour <= realSunsetHour

    readonly property var effectiveTimeBlend: debugMode ? debugTimeBlend : realTimeBlend

    readonly property string debugTimeOfDay: {
        var blend = debugTimeBlend;
        if (blend.day >= blend.evening && blend.day >= blend.night)
            return "Day";
        if (blend.evening >= blend.night)
            return "Evening";
        return "Night";
    }

    readonly property real effectiveSunProgress: debugMode ? debugSunProgress : realSunProgress
    readonly property string effectiveTimeOfDay: debugMode ? debugTimeOfDay : timeOfDay
    readonly property bool effectiveIsDay: debugMode ? debugIsDay : realIsDay
    readonly property int effectiveWeatherCode: debugMode ? debugWeatherCode : weatherCode
    readonly property string effectiveWeatherSymbol: debugMode ? getWeatherCodeEmoji(debugWeatherCode) : weatherSymbol
    readonly property string effectiveWeatherDescription: debugMode ? getWeatherDescription(debugWeatherCode) : weatherDescription

    // Weather effect types based on code
    readonly property string effectiveWeatherEffect: getWeatherEffect(effectiveWeatherCode)
    readonly property real effectiveWeatherIntensity: getWeatherIntensity(effectiveWeatherCode)

    function getWeatherEffect(code) {
        if (code === 0 || code === 1)
            return "clear";
        if (code === 2 || code === 3)
            return "clouds";
        if (code === 45 || code === 48)
            return "fog";
        if (code >= 51 && code <= 57)
            return "drizzle";
        if (code >= 61 && code <= 67)
            return "rain";
        if (code >= 71 && code <= 77)
            return "snow";
        if (code >= 80 && code <= 82)
            return "rain";
        if (code >= 85 && code <= 86)
            return "snow";
        if (code === 95)
            return "thunderstorm";
        if (code >= 96 && code <= 99)
            return "thunderstorm";
        return "clear";
    }

    function getWeatherIntensity(code) {
        if (code === 0 || code === 1)
            return 0.0;
        if (code === 2)
            return 0.5;
        if (code === 3)
            return 1.0;
        if (code === 45)
            return 0.5;
        if (code === 48)
            return 0.7;
        if (code === 51 || code === 56)
            return 0.3;
        if (code === 53)
            return 0.5;
        if (code === 55 || code === 57)
            return 0.7;
        if (code === 61)
            return 0.4;
        if (code === 63 || code === 66)
            return 0.6;
        if (code === 65 || code === 67)
            return 0.9;
        if (code === 71)
            return 0.3;
        if (code === 73)
            return 0.5;
        if (code === 75 || code === 77)
            return 0.8;
        if (code === 80)
            return 0.5;
        if (code === 81)
            return 0.7;
        if (code === 82)
            return 1.0;
        if (code === 85)
            return 0.6;
        if (code === 86)
            return 0.9;
        if (code === 95)
            return 0.8;
        if (code >= 96)
            return 1.0;
        return 0.0;
    }

    function getWeatherDescription(code) {
        if (code === 0)
            return "Clear sky";
        if (code === 1)
            return "Mainly clear";
        if (code === 2)
            return "Partly cloudy";
        if (code === 3)
            return "Overcast";
        if (code === 45)
            return "Foggy";
        if (code === 48)
            return "Rime fog";
        if (code >= 51 && code <= 53)
            return "Light drizzle";
        if (code === 55)
            return "Dense drizzle";
        if (code >= 56 && code <= 57)
            return "Freezing drizzle";
        if (code === 61)
            return "Light rain";
        if (code === 63)
            return "Moderate rain";
        if (code === 65)
            return "Heavy rain";
        if (code >= 66 && code <= 67)
            return "Freezing rain";
        if (code === 71)
            return "Light snow";
        if (code === 73)
            return "Moderate snow";
        if (code === 75)
            return "Heavy snow";
        if (code === 77)
            return "Snow grains";
        if (code >= 80 && code <= 81)
            return "Rain showers";
        if (code === 82)
            return "Heavy showers";
        if (code >= 85 && code <= 86)
            return "Snow showers";
        if (code === 95)
            return "Thunderstorm";
        if (code >= 96 && code <= 99)
            return "Thunderstorm with hail";
        return "Unknown";
    }

    function calculateSunPosition() {
        var now = new Date();
        var hour = now.getHours() + now.getMinutes() / 60;

        root.currentHour = hour;

        var sunriseH = sunrise.length > 0 ? parseTime(sunrise) : 6.0;
        var sunsetH = sunset.length > 0 ? parseTime(sunset) : 18.0;

        root.isDay = (hour >= sunriseH && hour <= sunsetH);
        root.sunProgress = calculateSunProgress(hour, sunriseH, sunsetH);

        var blend = calculateTimeBlend(hour);
        if (blend.day >= blend.evening && blend.day >= blend.night) {
            root.timeOfDay = "Day";
        } else if (blend.evening >= blend.night) {
            root.timeOfDay = "Evening";
        } else {
            root.timeOfDay = "Night";
        }
    }

    function getWeatherCodeEmoji(code) {
        if (code === 0)
            return "☀️";
        if (code === 1)
            return "🌤️";
        if (code === 2)
            return "⛅";
        if (code === 3)
            return "☁️";
        if (code === 45)
            return "🌫️";
        if (code === 48)
            return "🌨️";
        if (code >= 51 && code <= 53)
            return "🌦️";
        if (code === 55)
            return "🌧️";
        if (code >= 56 && code <= 57)
            return "🧊";
        if (code >= 61 && code <= 65)
            return "🌧️";
        if (code >= 66 && code <= 67)
            return "🧊";
        if (code >= 71 && code <= 77)
            return "❄️";
        if (code >= 80 && code <= 81)
            return "🌦️";
        if (code === 82)
            return "🌧️";
        if (code >= 85 && code <= 86)
            return "🌨️";
        if (code === 95)
            return "⛈️";
        if (code >= 96 && code <= 99)
            return "🌩️";
        return "❓";
    }

    function convertTemp(temp) {
        if (Config.weather.unit === "F") {
            return (temp * 9 / 5) + 32;
        }
        return temp;
    }

    function handleError() {
        if (retryCount < maxRetries) {
            retryCount++;
            retryTimer.start();
        } else {
            root.isLoading = false;
            root.hasFailed = true;
            retryCount = 0;
        }
    }

    property Process weatherProcess: Process {
        running: false
        command: []

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (root.wasCancelled) {
                    return;
                }

                var raw = text.trim();
                if (raw.length > 0) {
                    try {
                        var data = JSON.parse(raw);

                        if (data.error) {
                            console.warn("WeatherService:", data.error);
                            root.dataAvailable = false;
                            root.handleError();
                            return;
                        }

                        if (data.current_weather && data.daily) {
                            var weather = data.current_weather;
                            var daily = data.daily;

                            root.weatherCode = parseInt(weather.weathercode);
                            root.currentTemp = convertTemp(parseFloat(weather.temperature));
                            root.windSpeed = parseFloat(weather.windspeed);

                            if (daily.temperature_2m_max && daily.temperature_2m_max.length > 0) {
                                root.maxTemp = convertTemp(parseFloat(daily.temperature_2m_max[0]));
                            }
                            if (daily.temperature_2m_min && daily.temperature_2m_min.length > 0) {
                                root.minTemp = convertTemp(parseFloat(daily.temperature_2m_min[0]));
                            }

                            if (daily.sunrise && daily.sunrise.length > 0) {
                                root.sunrise = daily.sunrise[0].split("T")[1];
                            }
                            if (daily.sunset && daily.sunset.length > 0) {
                                root.sunset = daily.sunset[0].split("T")[1];
                            }

                            var forecastData = [];
                            var dayCount = Math.min(7, daily.time ? daily.time.length : 0);
                            for (var i = 0; i < dayCount; i++) {
                                // Manual date parse to avoid UTC midnight issues
                                // "YYYY-MM-DD"
                                var dateParts = daily.time[i].split("-");
                                var year = parseInt(dateParts[0]);
                                var month = parseInt(dateParts[1]) - 1;
                                var day = parseInt(dateParts[2]);
                                
                                var dayDate = new Date(year, month, day);
                                var rawDayName = i === 0 ? "Today" : dayDate.toLocaleDateString(Qt.locale(), "ddd");
                                var dayName = rawDayName.charAt(0).toUpperCase() + rawDayName.slice(1);
                                forecastData.push({
                                    date: daily.time[i],
                                    dayName: dayName,
                                    weatherCode: daily.weathercode ? daily.weathercode[i] : 0,
                                    emoji: getWeatherCodeEmoji(daily.weathercode ? daily.weathercode[i] : 0),
                                    maxTemp: convertTemp(daily.temperature_2m_max ? daily.temperature_2m_max[i] : 0),
                                    minTemp: convertTemp(daily.temperature_2m_min ? daily.temperature_2m_min[i] : 0)
                                });
                            }
                            root.forecast = forecastData;

                            root.weatherSymbol = getWeatherCodeEmoji(root.weatherCode);
                            root.weatherDescription = getWeatherDescription(root.weatherCode);
                            root.calculateSunPosition();
                            root.dataAvailable = true;
                            root.isLoading = false;
                            root.hasFailed = false;
                            root.retryCount = 0;
                        } else {
                            console.warn("WeatherService: Invalid response structure");
                            root.dataAvailable = false;
                            root.handleError();
                        }
                    } catch (e) {
                        console.warn("WeatherService: JSON parse error:", e);
                        root.dataAvailable = false;
                        root.handleError();
                    }
                } else {
                    console.warn("WeatherService: Empty response");
                    root.handleError();
                }
            }
        }

        onExited: function (code) {
            if (code !== 0 && code !== 15) {
                console.warn("WeatherService: Script exited with code", code);
                root.dataAvailable = false;
                root.handleError();
            }
            root.wasCancelled = false;
        }
    }

    property var weatherConfig: Config.weather
    readonly property string configLocation: weatherConfig ? weatherConfig.location : ""
    readonly property string configUnit: weatherConfig ? weatherConfig.unit : "C"
    property bool _initialized: false

    onConfigLocationChanged: {
        if (!_initialized) return;
        console.log("WeatherService: Location changed to '" + configLocation + "'");
        Qt.callLater(() => { updateWeather(); });
    }
    onConfigUnitChanged: {
        if (!_initialized) return;
        console.log("WeatherService: Unit changed to '" + configUnit + "'");
        Qt.callLater(() => { updateWeather(); });
    }

    function updateWeather() {
        // Data now comes from ryoku's live `Weather` singleton, not weather.sh.
        // If ryoku already has data, mirror it; otherwise ask ryoku to load.
        if (Weather.cc) {
            root.syncFromRyoku();
        } else {
            root.isLoading = true;
            root.hasFailed = false;
            Weather.reload();
        }
    }

    Timer {
        id: startupDelay
        interval: 2000
        running: true
        onTriggered: updateWeather()
    }

    Component.onCompleted: {
        var now = new Date();
        currentHour = now.getHours() + now.getMinutes() / 60;
        _initialized = true;

        // Pull whatever ryoku already has; reload if it hasn't loaded yet.
        if (Weather.cc) {
            syncFromRyoku();
        } else {
            Weather.reload();
        }
    }
}
