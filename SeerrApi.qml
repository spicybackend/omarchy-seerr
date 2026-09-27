import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: api
    signal requestSucceeded(string mediaType, int tmdbId, var request)
    signal keyVerificationFinished(string result)
    onRequestSucceeded: function(mediaType, tmdbId, request) { _updateSearchResult(mediaType, tmdbId, request) }
    property string authMode: "session"
    property bool keyringAvailable: false
    property var _apiKey: ""
    property string _pendingKeyOperation: ""
    property string _keyringOutput: ""
    property var _pendingKey: ""
    property string _keyringOrigin: ""
    property Process _secretProcess: Process {
        id: secretProcess
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => { api._keyringOutput += data + "\n" }
        }
        stderr: SplitParser {
            onRead: data => { api._keyringOutput += data + "\n" }
        }
        onStarted: {
            if (api._pendingKeyOperation === "store") write(String(api._pendingKey) + "\n")
            api._secretProcess.stdinEnabled = false
        }
        onExited: (exitCode, exitStatus) => api._secretProcessFinished(exitCode, exitStatus)
    }

    property string serverUrl: {
        try { return JSON.parse(configFile.text() || "{}").serverUrl || "" }
        catch (e) { return "" }
    }
    property bool authenticated: false
    property var user: null
    property bool busy: false
    property string error: ""
    property var searchResults: []
    property bool awaitingKeyStorageChoice: false
    property string _verifiedKeyForChoice: ""
    property bool _restoreAttempted: false
    property string _configWriteText: ""
    property var _configWriteCallback: null
    property Process _configProcess: Process {
        id: configProcess
        stdinEnabled: true
        stdout: SplitParser {}
        stderr: SplitParser {}
        command: ["sh", "-c", "mkdir -p \"$HOME/.config/omarchy/seerr-quick-requests\" && chmod 700 \"$HOME/.config/omarchy/seerr-quick-requests\" && umask 077 && cat > \"$HOME/.config/omarchy/seerr-quick-requests/config.json\" && chmod 600 \"$HOME/.config/omarchy/seerr-quick-requests/config.json\""]
        onStarted: {
            write(api._configWriteText)
            api._configWriteText = ""
            stdinEnabled = false
        }
        onExited: function(exitCode, exitStatus) {
            console.log("Seerr config write exit code=" + exitCode + " status=" + exitStatus)
            var callback = api._configWriteCallback
            api._configWriteCallback = null
            if (callback) callback(exitCode === 0)
        }
    }
    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/seerr-quick-requests/config.json"
        watchChanges: true
        printErrors: false
    }
    property var requests: []

    property var _xhr: null
    property var _lookupCache: ({})
    property var _detailXhrs: []
    property var _pendingKeyCallback: null
    property var _queuedSecretAction: null

    function _baseUrl(value) {
        var url = String(value || "").trim().replace(/\/+$/, "")
        if (!/^https?:\/\//i.test(url)) throw new Error("Enter a valid Seerr URL including http:// or https://.")
        var apiPath = url.indexOf("/api/v1")
        if (apiPath >= 0 && apiPath + 7 === url.length) url = url.substring(0, apiPath)
        return url
    }

    function _url(path) {
        return apiUrl(serverUrl, path)
    }

    function apiUrl(baseValue, path) {
        var base = _baseUrl(baseValue)
        return base + (path.indexOf("/api/v1/") === 0 ? path.substring(7) : "/api/v1" + path)
    }

    function _writeConfig(value, callback) {
        if (_configProcess.running) { if (callback) callback(false); return }
        _configProcess.stdinEnabled = true
        _configWriteText = JSON.stringify(value, null, 2) + "\n"
        _configWriteCallback = callback || null
        _configProcess.running = true
    }


    function _fail(message) {
        busy = false
        error = message
        _xhr = null
    }


    function _secretArgs(action, base) {
        var origin = new URL(base).origin.toLowerCase()
        var args = ["secret-tool", action]
        if (action === "store") args.push("--label=Omarchy Seerr API key")
        args.push("service", "spicybackend.seerr", "server", origin)
        return args
    }

    function _startSecret(action, base, secret, callback) {
        if (_secretProcess.running) {
            _queuedSecretAction = { action: action, base: base, secret: secret, callback: callback }
            console.log("Seerr keyring queued " + action + " (busy)")
            return true
        }
        try {
            _keyringOrigin = new URL(_baseUrl(base)).origin.toLowerCase()
            _secretProcess.command = _secretArgs(action, _baseUrl(base))
        } catch (e) { if (callback) callback(false, "Invalid server URL for Secret Service."); return false }
        _pendingKeyOperation = action
        _keyringOutput = ""
        _pendingKeyCallback = callback
        _pendingKey = action === "store" ? String(secret || "") : ""
        console.log("Seerr keyring starting " + action)
        _secretProcess.stdinEnabled = true
        _secretProcess.running = true
        return true
    }
    function _secretProcessFinished(code, exitStatus) {
        var action = _pendingKeyOperation
        _pendingKeyOperation = ""
        keyringAvailable = code === 0 || (action === "lookup" && code === 1)
        console.log("Seerr keyring " + action + " exit code=" + code + " status=" + exitStatus + " ok=" + keyringAvailable + " output='" + _keyringOutput.replace(/\r?\n/g, " ") + "'")
        var output = _keyringOutput.replace(/\r?\n$/, "")
        _keyringOutput = ""
        var callback = _pendingKeyCallback
        _pendingKeyCallback = null
        if (action === "store") _pendingKey = ""
        if (callback) callback(keyringAvailable, action === "lookup" && code === 0 ? output : "")
        var queued = _queuedSecretAction
        _queuedSecretAction = null
        if (queued) {
            Qt.callLater(function() {
                api._startSecret(queued.action, queued.base, queued.secret, queued.callback)
            })
        }
    }
    function _secretProcessFailed() {
        var action = _pendingKeyOperation
        _pendingKeyOperation = ""
        if (action === "store") _pendingKey = ""
        if (action !== "store") _apiKey = ""
        keyringAvailable = false
        var callback = _pendingKeyCallback
        _pendingKeyCallback = null
        if (callback) callback(false, "Secret Service is unavailable.")
    }

    function _keyHeader(xhr) {
        if (_apiKey) xhr.setRequestHeader("X-Api-Key", _apiKey)
    }

    function _year(date) {
        var match = String(date || "").match(/^(\d{4})/)
        return match ? Number(match[1]) : null
    }

    function _seasonNumbers(seasons) {
        if (!Array.isArray(seasons)) return []
        return seasons.map(function(s) { return typeof s === "number" ? s : Number(s.seasonNumber) })
                       .filter(function(n) { return isFinite(n) })
    }

    function _isReleased(date) {
        if (!date) return true
        var d = new Date(date)
        if (!isNaN(d.getTime())) return d <= new Date()
        var year = _year(date)
        if (year) return year <= new Date().getFullYear()
        return true
    }

    function _statusLabel(mediaInfo, isReleased) {
        if (isReleased === false) return "Not yet released"
        var status = Number(mediaInfo && mediaInfo.status)
        if (status === 5) return "Available"
        if (status === 4) return "Partially available"
        if (status === 3) return "Requested"
        if (status === 2) return "Pending"
        return "Not requested"
    }

    function _normalize(item, requestItem) {
        var type = String(item.mediaType || (item.mediaInfo && item.mediaInfo.mediaType) || "tv")
        var title = type === "movie" ? (item.title || item.name) : (item.name || item.title)
        var date = type === "movie" ? (item.releaseDate || item.release_date) : (item.firstAirDate || item.first_air_date)
        var mediaInfo = item.mediaInfo || item.media || {}
        var requested = Number(mediaInfo.status) >= 2 && Number(mediaInfo.status) <= 5 || (mediaInfo.requests || []).length > 0
        var isReleased = _isReleased(date)
        var existingRequest = (mediaInfo.requests && mediaInfo.requests[0]) || {}
        var existingRequestId = Number(existingRequest.id) || Number(item.requestId) || 0
        var normalized = Object.assign({}, item, {
            mediaType: type,
            title: String(title || "Unknown title"),
            year: _year(date),
            posterUrl: item.posterPath ? "https://image.tmdb.org/t/p/w185/" + String(item.posterPath).replace(/^\/+/, "") : "",
            alreadyRequested: requestItem ? true : requested,
            status: Number(mediaInfo.status),
            requestId: existingRequestId,
            requestedSeasons: _seasonNumbers(existingRequest.seasons).length ? _seasonNumbers(existingRequest.seasons) : _seasonNumbers(item.requestedSeasons),
            statusLabel: requestItem ? _requestStatus(mediaInfo, isReleased) : (requested ? _statusLabel(mediaInfo, isReleased) : "Not requested")
        })
        return normalized
    }

    function _requestStatus(mediaInfo, isReleased) {
        if (isReleased === false) return "Not yet released"
        var status = Number(mediaInfo && mediaInfo.status)
        if (status === 5) return "Available"
        if (status === 4) return "Partially available"
        if (status === 3) return "Requested"
        if (status === 2) return "Pending"
        return "Requested"
    }

    function _normalizeRequest(item) {
        var info = item.mediaInfo || item.media || {}
        var type = String(item.mediaType || info.mediaType || "tv")
        var id = Number(info.tmdbId || item.tmdbId || item.mediaId || info.id)
        var cached = null
        for (var i = 0; i < searchResults.length; ++i) {
            var result = searchResults[i]
            if (result.mediaType === type && Number(result.id) === id) { cached = result; break }
        }
        var mediaInfo = Object.assign({}, info, { status: info.status || item.status })
        var enriched = Object.assign({}, cached || {}, info, {
            id: id,
            tmdbId: id,
            requestId: Number(item.id) || 0,
            requestedSeasons: _seasonNumbers(item.seasons),
            mediaId: Number(info.id) || 0,
            mediaType: type,
            mediaInfo: mediaInfo,
            title: info.title || info.name || (cached && cached.title) || item.title || item.name || "",
            releaseDate: info.releaseDate || info.release_date || (cached && (cached.releaseDate || cached.release_date)),
            firstAirDate: info.firstAirDate || info.first_air_date || (cached && (cached.firstAirDate || cached.first_air_date)),
            posterPath: info.posterPath || info.poster_path || (cached && (cached.posterPath || cached.poster_path)),
            status: mediaInfo.status
        })
        return _normalize(enriched, true)
    }

    function _isRequested(type, id) {
        for (var i = 0; i < requests.length; ++i) {
            var media = requests[i].mediaInfo || requests[i].media || requests[i]
            if (requests[i].mediaType === type && Number(media.tmdbId || media.id || requests[i].tmdbId) === id) return true
        }
        return false
    }

    function _updateSearchResult(mediaType, tmdbId, request) {
        var type = String(mediaType)
        var id = Number(tmdbId)
        var info = request && request.mediaInfo ? request.mediaInfo : (request && request.media ? request.media : {})
        var newStatus = Number(info.status) || 2
        var newRequestId = Number(request && request.id) || 0
        var newRequestedSeasons = _seasonNumbers(request && request.seasons)
        for (var i = 0; i < searchResults.length; ++i) {
            var r = searchResults[i]
            if (r.mediaType === type && Number(r.id) === id) {
                var updated = searchResults.slice()
                updated[i] = Object.assign({}, r, {
                    alreadyRequested: true,
                    status: newStatus,
                    requestId: newRequestId,
                    requestedSeasons: newRequestedSeasons,
                    statusLabel: _statusLabel(info, true)
                })
                searchResults = updated
                break
            }
        }
    }

    function _enrichRequestRows(rows) {
        requests = rows
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            if (row.title && row.title !== "Unknown title") continue
            var key = row.mediaType + ":" + row.id
            if (_lookupCache[key]) {
                var cached = Object.assign({}, row, _lookupCache[key], { mediaType: row.mediaType, mediaInfo: row.mediaInfo, status: row.status })
                rows[i] = _normalize(cached, true)
                continue
            }
            _fetchRequestDetail(row, i, key, rows)
        }
        requests = rows.slice()
    }

    function _fetchRequestDetail(row, index, key, rows) {
        var xhr = new XMLHttpRequest()
        _detailXhrs.push(xhr)
        xhr.withCredentials = true
        try {
            xhr.open("GET", _url("/" + row.mediaType + "/" + row.id))
            xhr.setRequestHeader("Accept", "application/json")
            _keyHeader(xhr)
        } catch (e) {
            _detailXhrs.splice(_detailXhrs.indexOf(xhr), 1)
            return
        }
        xhr.timeout = 20000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status >= 200 && xhr.status < 300) {
                try {
                    var detail = JSON.parse(xhr.responseText)
                    _lookupCache[key] = detail
                    rows[index] = _normalize(Object.assign({}, row, detail, { mediaType: row.mediaType, mediaInfo: row.mediaInfo, status: row.status }), true)
                    requests = rows.slice()
                } catch (e) {}
            }
            _detailXhrs.splice(_detailXhrs.indexOf(xhr), 1)
        }
        xhr.onerror = function() { _detailXhrs.splice(_detailXhrs.indexOf(xhr), 1) }
        xhr.ontimeout = xhr.onerror
        xhr.send()
    }

    function _httpError(status, message) {
        var body = String(message || "")
        if (Number(status) === 401 || /cookie ['\\"]connect\.sid['\\"] required/i.test(body))
            return "Seerr rejected the API key (HTTP 401). Check that this key is valid for this Seerr instance and supports API authentication."
        return body || ("Seerr returned HTTP " + (Number(status) || "network error") + ".")
    }

    function _send(method, path, payload, operation, onSuccess, onError, independent) {
        if (busy && !independent) {
            error = "Please wait for the current request to finish."
            return
        }
        if (!independent) {
            busy = true
            _xhr = null
        }
        error = ""
        if (operation === "keyverify") error = "Checking Seerr API key…"
        var requestUrl
        try {
            requestUrl = _url(path)
        } catch (e) {
            if (!independent) _fail(String(e.message || e))
            if (onError) onError()
            return
        }
        var xhr
        try {
            xhr = new XMLHttpRequest()
            xhr.withCredentials = true
            xhr.open(method, requestUrl)
            xhr.setRequestHeader("Accept", "application/json")
            if (payload !== null) xhr.setRequestHeader("Content-Type", "application/json")
            _keyHeader(xhr)
        } catch (e) {
            if (!independent) _fail(String(e.message || "Could not start the Seerr request."))
            if (onError) onError()
            return
        }
        if (!independent) _xhr = xhr
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (independent) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try { onSuccess(xhr.responseText ? JSON.parse(xhr.responseText) : null) }
                    catch (e) { if (onError) onError() }
                } else if (onError) onError()
                return
            }
            if (_xhr !== xhr) return
            _xhr = null
            busy = false
            if (xhr.status < 200 || xhr.status >= 300) {
                var message = ""
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response.message) message = String(response.message)
                    else if (response.error) message = String(response.error)
                } catch (e) {}
                if (!xhr.status) message = "Could not reach Seerr. Check the server URL and network connection."
                if (operation === "restore" || operation === "keyverify") {
                    authenticated = false
                    user = null
                }
                if (operation === "restore" && xhr.status === 401)
                    error = "No saved API key worked for this Seerr server. Enter a valid API key."
                else if (operation === "keyverify")
                    error = _httpError(xhr.status, message)
                else
                    error = _httpError(xhr.status, message)
                if (onError) onError()
                return
            }
            var data = null
            if (xhr.responseText) {
                try { data = JSON.parse(xhr.responseText) }
                catch (e) {
                    error = "Seerr returned an invalid response."
                    if (onError) onError()
                    if (!independent) { busy = false; _xhr = null }
                    return
                }
            }
            onSuccess(data)
        }
        if (!independent) {
            xhr.onerror = function() {
                if (_xhr !== xhr) return
                _fail("Could not reach Seerr. Check the server URL and network connection.")
                if (onError) onError()
            }
            xhr.ontimeout = function() {
                if (_xhr !== xhr) return
                _fail("The Seerr request timed out.")
                if (onError) onError()
            }
        }
        xhr.timeout = 20000
        xhr.send(payload === null ? "" : JSON.stringify(payload))
    }
    function restore() {
        if (_restoreAttempted || authenticated || awaitingKeyStorageChoice || busy) return
        _restoreAttempted = true
        if (!serverUrl) { error = "Enter your Seerr server URL and API key."; return }
        _startSecret("lookup", serverUrl, "", function(ok, secret) {
            keyringAvailable = ok
            if (ok && secret) _verifyApiKey(secret, "keyring")
            else if (!ok) error = "Secret Service is unavailable. Unlock your desktop keyring and retry."
        })
    }

    function loginWithApiKey(url, apiKey) {
        if (busy) { error = "Please wait for the current request to finish."; keyVerificationFinished(error); return }
        _restoreAttempted = true
        var key = String(apiKey || "").trim()
        if (!key) { error = "Enter a Seerr API key."; keyVerificationFinished(error); return }
        var validatedUrl
        try { validatedUrl = _baseUrl(url) } catch (e) { error = String(e.message || e); keyVerificationFinished(error); return }
        _writeConfig({ serverUrl: validatedUrl }, function(ok) {
            if (!ok) { error = "Could not write the instance URL safely."; keyVerificationFinished(error); return }
            api._verifyApiKey(key, "choice")
        })
    }

    function _verifyApiKey(key, storage) {
        _apiKey = String(key)
        authMode = "verifying"
        _send("GET", "/auth/me", null, "keyverify", function(data) {
            busy = false
            if (!data) {
                _apiKey = ""
                error = "Seerr API key did not return a signed-in user."
                keyVerificationFinished(error)
                return
            }
            user = data
            if (storage === "choice") {
                _verifiedKeyForChoice = key
                awaitingKeyStorageChoice = true
                authMode = "choice"
                error = ""
                keyVerificationFinished("verified")
            } else {
                authMode = storage
                authenticated = true
                keyVerificationFinished("verified")
                refreshRequests()
            }
        }, function() {
            _apiKey = ""
            error = "The API key was rejected or /auth/me did not return a user."
            keyVerificationFinished(error)
        })
    }

    function chooseKeyStorage(choice) {
        if (!awaitingKeyStorageChoice || !_verifiedKeyForChoice) return
        if (choice === "keyring") {
            _startSecret("store", serverUrl, _verifiedKeyForChoice, function(ok) {
                if (!ok) {
                    error = "Could not save in the keyring. Use this session only or sign out and retry."
                    return
                }
                _writeConfig({ serverUrl: serverUrl }, function(ok) {
                    if (!ok) { error = "Could not write configuration with safe permissions."; return }
                    _completeKeyLogin("keyring")
                })
            })
        } else if (choice === "none") {
            _writeConfig({ serverUrl: serverUrl }, function(ok) {
                if (!ok) { error = "Could not write configuration with safe permissions."; return }
                _completeKeyLogin("session")
            })
        }
    }

    function _completeKeyLogin(mode) {
        authMode = mode
        authenticated = true
        awaitingKeyStorageChoice = false
        error = ""
        if (mode === "session") _apiKey = _verifiedKeyForChoice
        _verifiedKeyForChoice = ""
        refreshRequests()
    }



    function search(query) {
        var q = String(query || "").trim()
        if (!authenticated) return
        if (!q) { searchResults = []; return }
        _send("GET", "/search?query=" + encodeURIComponent(q), null, "search", function(data) {
            var results = data && data.results ? data.results : []
            searchResults = results.filter(function(item) { return item.mediaType === "tv" || item.mediaType === "movie" })
                .map(function(item) { return _normalize(item, false) })
        })
    }

    function refreshRequests() {
        if (authenticated) _fetchRequestPage(0, [])
    }

    function _fetchRequestPage(skip, collected) {
        _send("GET", "/request?mediaType=all&take=100&skip=" + skip, null, "requests", function(data) {
            var page = data && data.results ? data.results : []
            var all = collected.concat(page)
            var total = data && data.pageInfo ? Number(data.pageInfo.results) : all.length
            if (all.length < total && page.length) { _fetchRequestPage(all.length, all); return }
            var normalized = all.map(function(item) { return _normalizeRequest(item) })
            requests = normalized
            _enrichRequestRows(normalized)
        })
    }

    function requestMedia(mediaType, tmdbId, seasons, requestId, requestedSeasons, replace) {
        var type = String(mediaType || "")
        var id = Number(tmdbId)
        if (!authenticated || (type !== "movie" && type !== "tv") || !isFinite(id) || id <= 0) {
            error = "Choose a valid movie or TV show to request."
            return
        }
        var rid = Number(requestId) || 0
        if (rid > 0 && type === "tv") {
            var existing = Array.isArray(requestedSeasons) ? requestedSeasons : []
            var selected = Array.isArray(seasons) ? seasons : []
            var updated = replace ? selected : existing.concat(selected).filter(function(v, i, a) { return a.indexOf(v) === i })
            _send("PUT", "/request/" + rid, { seasons: updated.length ? updated : "all" }, "update", function(data) {
                requestSucceeded(type, id, data)
                refreshRequests()
            })
            return
        }
        if (_isRequested(type, id)) { error = "This " + type + " already has a request."; return }
        for (var i = 0; i < searchResults.length; ++i) {
            var result = searchResults[i]
            if (result.mediaType === type && Number(result.id) === id && result.alreadyRequested) {
                error = "This " + type + " already has a request."
                return
            }
        }
        var payload = { mediaType: type, mediaId: id }
        if (type === "tv") {
            if (Array.isArray(seasons) && seasons.length) payload.seasons = seasons
            else payload.seasons = "all"
        }
        _send("POST", "/request", payload, "create", function(data) {
            if (data) requests = [_normalizeRequest(data)].concat(requests)
            requestSucceeded(type, id, data)
            refreshRequests()
        })
    }

    function fetchTvSeasons(tmdbId, callback) {
        var id = Number(tmdbId)
        if (!isFinite(id) || id <= 0) { if (callback) callback([]); return }
        _send("GET", "/tv/" + id, null, "tvseasons", function(data) {
            var rawSeasons = data && Array.isArray(data.seasons) ? data.seasons : []
            var mediaSeasons = data && data.mediaInfo && Array.isArray(data.mediaInfo.seasons) ? data.mediaInfo.seasons : []
            var availableMap = {}
            mediaSeasons.forEach(function(s) { if (Number(s.status) === 5) availableMap[Number(s.seasonNumber)] = true })
            callback(rawSeasons.filter(function(s) { return Number(s.seasonNumber) >= 0 })
                               .map(function(s) {
                                   var sn = Number(s.seasonNumber)
                                   return { seasonNumber: sn, name: String(s.name || ""), available: !!availableMap[sn] }
                               })
                               .sort(function(a, b) { return b.seasonNumber - a.seasonNumber }))
        }, function() { if (callback) callback([]) }, true)
    }

    function deleteRequest(requestId, mediaId, deleteFiles) {
        var id = Number(requestId)
        var mid = Number(mediaId) || 0
        if (!authenticated || !isFinite(id) || id <= 0) {
            error = "Cannot remove this request."
            return
        }
        _send("DELETE", "/request/" + id, null, "delete", function() {
            requests = requests.filter(function(row) { return Number(row.requestId) !== id })
            if (deleteFiles && mid > 0) {
                _send("DELETE", "/media/" + mid + "/file", null, "deletefile", function() {}, function() {
                    error = "Request removed, but deleting files from Radarr/Sonarr failed."
                }, true)
            }
        })
    }

    function logout() {
        if (!authenticated) return
        var oldMode = authMode
        var oldUrl = serverUrl
        _send("POST", "/auth/logout", null, "logout", function() {
            authenticated = false
            user = null
            requests = []
            searchResults = []
            _apiKey = ""
            awaitingKeyStorageChoice = false
            _verifiedKeyForChoice = ""
            _restoreAttempted = false
            if (oldMode === "keyring") {
                authMode = "session"
                _startSecret("clear", oldUrl, "", function(ok) {
                    keyringAvailable = ok
                    if (!ok) error = "Signed out, but the saved key could not be removed from the keyring."
                })
            } else {
                authMode = "session"
            }
        })
    }
}
