import QtQuick

Item {
    id: root
    width: 0
    height: 0
    visible: false

    property bool online: true
    readonly property string phase: internalPhase
    readonly property bool running: internalPhase === "latency"
                                    || internalPhase === "download"
                                    || internalPhase === "upload"
    readonly property string edgeCode: internalEdgeCode
    readonly property string countryCode: internalCountryCode
    readonly property real pingMs: internalPingMs
    readonly property real downloadMbps: internalDownloadMbps
    readonly property real uploadMbps: internalUploadMbps
    readonly property string errorText: internalErrorText

    readonly property string downloadEndpoint: "https://speed.cloudflare.com/__down"
    readonly property string uploadEndpoint: "https://speed.cloudflare.com/__up"

    property string internalPhase: online ? "idle" : "offline"
    property string internalEdgeCode: ""
    property string internalCountryCode: ""
    property real internalPingMs: 0
    property real internalDownloadMbps: 0
    property real internalUploadMbps: 0
    property string internalErrorText: ""

    property int runGeneration: 0
    property var activeRequest: null
    property var requestTimeoutHandler: null

    property int latencyStep: 0
    property var latencySamples: []
    property var downloadSizes: [1000000, 5000000, 10000000, 25000000]
    property int downloadIndex: 0
    property int downloadRepeats: 0
    property int selectedDownloadBytes: 0
    property var downloadSamples: []
    property var uploadSizes: [250000, 1000000, 5000000, 10000000]
    property int uploadIndex: 0
    property int uploadRepeats: 0
    property int selectedUploadBytes: 0
    property var uploadSamples: []

    function median(values) {
        var sorted = values.slice()
        sorted.sort(function(a, b) { return a - b })
        return sorted[Math.floor(sorted.length / 2)]
    }

    function readHeader(xhr, names) {
        for (var i = 0; i < names.length; ++i) {
            var value = xhr.getResponseHeader(names[i])
            if (value) return value
        }
        return ""
    }

    function captureLocation(result) {
        var edge = result.edge.trim().toUpperCase()
        var country = result.country.trim().toUpperCase()
        if (/^[A-Z]{3}$/.test(edge)) internalEdgeCode = edge
        if (/^[A-Z]{2}$/.test(country)) internalCountryCode = country
    }

    function finishFailure(nextPhase, message) {
        ++runGeneration
        requestTimer.stop()
        overallTimer.stop()
        requestTimeoutHandler = null
        var request = activeRequest
        activeRequest = null
        if (request) request.abort()
        internalErrorText = message
        internalPhase = nextPhase
        console.warn("Cloudflare speed test: " + message)
    }

    function finishSuccess() {
        requestTimer.stop()
        overallTimer.stop()
        activeRequest = null
        requestTimeoutHandler = null
        internalErrorText = ""
        internalPhase = "success"
    }

    function retryRequest(method, url, body, binary, onSuccess, attempt, message) {
        if (attempt < 1) {
            var generation = runGeneration
            Qt.callLater(function() {
                if (generation === runGeneration && running)
                    sendRequest(method, url, body, binary, onSuccess, attempt + 1)
            })
        } else {
            finishFailure("error", message)
        }
    }

    function sendRequest(method, url, body, binary, onSuccess, attempt) {
        var generation = runGeneration
        var xhr = new XMLHttpRequest()
        var startedAt = 0
        var headersAt = 0
        var timedOut = false

        xhr.onreadystatechange = function() {
            if (generation !== runGeneration || timedOut) return
            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED && headersAt === 0)
                headersAt = Date.now()
            if (xhr.readyState !== XMLHttpRequest.DONE) return

            requestTimer.stop()
            requestTimeoutHandler = null
            if (activeRequest === xhr) activeRequest = null
            var finishedAt = Date.now()

            if (xhr.status !== 200 || headersAt === 0) {
                xhr.onreadystatechange = null
                retryRequest(method, url, body, binary, onSuccess, attempt,
                             xhr.status === 0 ? "Network request failed" : "Service unavailable")
                return
            }

            var responseBytes = 0
            if (binary && xhr.response) responseBytes = xhr.response.byteLength || 0
            var result = {
                startedAt: startedAt,
                headersAt: headersAt,
                finishedAt: finishedAt,
                responseBytes: responseBytes,
                edge: readHeader(xhr, ["cf-meta-colo", "colo"]),
                country: readHeader(xhr, ["cf-meta-country", "country"])
            }
            xhr.onreadystatechange = null
            onSuccess(result)
        }

        xhr.open(method, url, true)
        if (binary) xhr.responseType = "arraybuffer"
        if (method === "POST") xhr.setRequestHeader("Content-Type", "application/octet-stream")

        activeRequest = xhr
        requestTimeoutHandler = function() {
            if (generation !== runGeneration) return
            timedOut = true
            requestTimer.stop()
            if (activeRequest === xhr) activeRequest = null
            xhr.abort()
            if (attempt < 1)
                sendRequest(method, url, body, binary, onSuccess, attempt + 1)
            else
                finishFailure("timeout", "Request timed out")
        }

        startedAt = Date.now()
        requestTimer.restart()
        if (body === null || body === undefined) xhr.send()
        else xhr.send(body)
    }

    function start() {
        if (running) return
        if (!online) {
            internalPhase = "offline"
            return
        }

        ++runGeneration
        internalEdgeCode = ""
        internalCountryCode = ""
        internalPingMs = 0
        internalDownloadMbps = 0
        internalUploadMbps = 0
        internalErrorText = ""
        latencyStep = 0
        latencySamples = []
        overallTimer.restart()
        internalPhase = "latency"
        runLatencyRequest()
    }

    function cancel() {
        if (!running) return
        ++runGeneration
        requestTimer.stop()
        overallTimer.stop()
        requestTimeoutHandler = null
        var request = activeRequest
        activeRequest = null
        if (request) request.abort()
        internalErrorText = ""
        internalPhase = "cancelled"
    }

    function runLatencyRequest() {
        sendRequest("GET", downloadEndpoint + "?bytes=0", null, false, function(result) {
            captureLocation(result)
            if (latencyStep > 0) {
                var elapsed = result.headersAt - result.startedAt
                if (!(elapsed > 0) || !isFinite(elapsed)) {
                    finishFailure("error", "Invalid latency result")
                    return
                }
                latencySamples.push(elapsed)
            }

            if (latencyStep < 7) {
                ++latencyStep
                runLatencyRequest()
            } else {
                internalPingMs = median(latencySamples)
                startDownload()
            }
        }, 0)
    }

    function measureDownload(bytes, onSuccess, measurementAttempt) {
        sendRequest("GET", downloadEndpoint + "?bytes=" + bytes, null, true, function(result) {
            captureLocation(result)
            // Cloudflare reference: download duration = ping + payload time (calcDownloadDuration).
            // payloadTime alone still drives calibration (>=500 ms of real transfer), so the
            // selected payload size is byte-for-byte unchanged; only the reported value matches CF.
            var payloadTime = result.finishedAt - result.headersAt
            var value = result.responseBytes * 8 / (internalPingMs + payloadTime) / 1000
            if (!(payloadTime > 0) || !(result.responseBytes > 0) || !(value > 0) || !isFinite(value)) {
                if (measurementAttempt < 1)
                    measureDownload(bytes, onSuccess, measurementAttempt + 1)
                else
                    finishFailure("error", "Invalid download result")
                return
            }
            onSuccess(value, payloadTime)
        }, 0)
    }

    function startDownload() {
        internalPhase = "download"
        downloadIndex = 0
        downloadSamples = []
        runDownloadCalibration()
    }

    function runDownloadCalibration() {
        var bytes = downloadSizes[downloadIndex]
        measureDownload(bytes, function(value, duration) {
            if (duration >= 500 || downloadIndex === downloadSizes.length - 1) {
                selectedDownloadBytes = bytes
                downloadSamples = [value]
                downloadRepeats = 2
                runDownloadRepeat()
            } else {
                ++downloadIndex
                runDownloadCalibration()
            }
        }, 0)
    }

    function runDownloadRepeat() {
        if (downloadRepeats === 0) {
            internalDownloadMbps = median(downloadSamples)
            startUpload()
            return
        }
        measureDownload(selectedDownloadBytes, function(value) {
            downloadSamples.push(value)
            --downloadRepeats
            runDownloadRepeat()
        }, 0)
    }

    function measureUpload(bytes, onSuccess, measurementAttempt) {
        var body = "0".repeat(bytes)
        sendRequest("POST", uploadEndpoint + "?bytes=" + bytes, body, false, function(result) {
            captureLocation(result)
            // Cloudflare reference: upload duration = full TTFB (calcUploadDuration), no ping subtraction.
            // Calibration still gates on transfer time (ttfb - ping) so the selected size is unchanged.
            var ttfb = result.headersAt - result.startedAt
            var value = bytes * 8 / ttfb / 1000
            body = null
            if (!(ttfb > 0) || !(value > 0) || !isFinite(value)) {
                if (measurementAttempt < 1)
                    measureUpload(bytes, onSuccess, measurementAttempt + 1)
                else
                    finishFailure("error", "Invalid upload result")
                return
            }
            onSuccess(value, ttfb - internalPingMs)
        }, 0)
    }

    function startUpload() {
        internalPhase = "upload"
        uploadIndex = 0
        uploadSamples = []
        runUploadCalibration()
    }

    function runUploadCalibration() {
        var bytes = uploadSizes[uploadIndex]
        measureUpload(bytes, function(value, duration) {
            if (duration >= 500 || uploadIndex === uploadSizes.length - 1) {
                selectedUploadBytes = bytes
                uploadSamples = [value]
                uploadRepeats = 2
                runUploadRepeat()
            } else {
                ++uploadIndex
                runUploadCalibration()
            }
        }, 0)
    }

    function runUploadRepeat() {
        if (uploadRepeats === 0) {
            internalUploadMbps = median(uploadSamples)
            finishSuccess()
            return
        }
        measureUpload(selectedUploadBytes, function(value) {
            uploadSamples.push(value)
            --uploadRepeats
            runUploadRepeat()
        }, 0)
    }

    onOnlineChanged: {
        if (!online) {
            if (running) finishFailure("offline", "Offline")
            else internalPhase = "offline"
        } else if (internalPhase === "offline") {
            internalErrorText = ""
            internalPhase = "idle"
        }
    }

    Timer {
        id: requestTimer
        interval: 15000
        repeat: false
        onTriggered: if (root.requestTimeoutHandler) root.requestTimeoutHandler()
    }

    Timer {
        id: overallTimer
        interval: 90000
        repeat: false
        onTriggered: root.finishFailure("timeout", "Test timed out")
    }
}

