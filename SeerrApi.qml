import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: api
    signal requestSucceeded(int tmdbId, var request)

    property string serverUrl: {
        try { return JSON.parse(configFile.text() || "{}").serverUrl || "" }
        catch (e) { return "" }
    }
    property bool authenticated: false
    property var user: null
    property bool busy: false
    property string error: ""
    property var searchResults: []
    property var requests: []

    property string _operation: ""
    property var _xhr: null

    property FileView configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/omarchy/seerr-quick-requests.json"
        watchChanges: false
        printErrors: false
    }

    function _baseUrl(value) {
        var url = String(value || "").trim().replace(/\/+$/, "")
        if (!/^https?:\/\//i.test(url))
            throw new Error("Enter a valid Seerr URL including http:// or https://.")
        var apiPath = url.indexOf("/api/v1")
        if (apiPath >= 0 && apiPath + 7 === url.length)
            url = url.substring(0, apiPath)
        return url
    }

    function _url(path) {
        return apiUrl(serverUrl, path)
    }

    function apiUrl(baseValue, path) {
        var base = _baseUrl(baseValue)
        return base + (path.indexOf("/api/v1/") === 0 ? path.substring(7) : "/api/v1" + path)
    }

    function _fail(message) {
        busy = false
        error = message
        _operation = ""
        _xhr = null
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
                var message = "Seerr returned HTTP " + (xhr.status || "network error") + "."
                try {
                    var response = JSON.parse(xhr.responseText)
                    if (response.message) message = String(response.message)
                    else if (response.error) message = String(response.error)
                } catch (e) {
                    if (!xhr.status) message = "Could not reach Seerr. Check the server URL and network connection."
                }
                if (operation === "restore" && xhr.status === 401) {
                    authenticated = false
                    user = null
                    error = "Sign in to Seerr to continue."
                } else {
                    error = message
                    if (operation === "restore" || operation === "login") {
                        authenticated = false
                        user = null
                    }
                }
                if (onError) onError()
                return
            }
            var data = null
            if (xhr.responseText) {
                try { data = JSON.parse(xhr.responseText) }
                catch (e) {
                    error = "Seerr returned an invalid response."
                    if (onError) onError()
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
        if (!serverUrl)
            return
        _send("GET", "/auth/me", null, "restore", function(data) {
            user = data
            authenticated = !!data
            if (authenticated)
                refreshRequests()
        })
    }

    function login(url, email, password) {
        if (busy) {
            error = "Please wait for the current request to finish."
            return
        }
        try {
            serverUrl = _baseUrl(url)
        } catch (e) {
            error = String(e.message || e)
            return
        }
        configFile.setText(JSON.stringify({ serverUrl: serverUrl }))
        _send("POST", "/auth/local", { email: String(email), password: String(password) }, "login", function(data) {
            user = data
            authenticated = !!data
            password = ""
            if (authenticated)
                refreshRequests()
        })
    }

    function search(query) {
        var q = String(query || "").trim()
        if (!authenticated)
            return
        if (!q) {
            searchResults = []
            return
        }
        _send("GET", "/search?query=" + encodeURIComponent(q), null, "search", function(data) {
            var results = data && data.results ? data.results : []
            searchResults = results.filter(function(item) { return item.mediaType === "tv" })
        })
    }

    function refreshRequests() {
        if (authenticated)
            _fetchRequestPage(0, [])
    }

    function _fetchRequestPage(skip, collected) {
        _send("GET", "/request?mediaType=tv&take=100&skip=" + skip, null, "requests", function(data) {
            var page = data && data.results ? data.results : []
            var all = collected.concat(page)
            var total = data && data.pageInfo ? Number(data.pageInfo.results) : all.length
            if (all.length < total && page.length > 0) {
                _fetchRequestPage(all.length, all)
                return
            }
            requests = all
        })
    }


    function requestShow(tmdbId) {
        var id = Number(tmdbId)
        if (!authenticated || !isFinite(id) || id <= 0) {
            error = "A valid TV show is required."
            return
        }
        for (var i = 0; i < requests.length; ++i) {
            var media = requests[i].mediaInfo || requests[i].media || {}
            if (Number(media.tmdbId || media.id) === id) {
                error = "This TV show already has a request."
                return
            }
        }
        for (var j = 0; j < searchResults.length; ++j) {
            var result = searchResults[j]
            var resultMedia = result.mediaInfo || {}
            var status = Number(resultMedia.status)
            if (Number(result.id) === id && ((status >= 2 && status <= 5) ||
                                              (resultMedia.requests || []).length > 0)) {
                error = "This TV show already has a request."
                return
            }
        }
        _send("POST", "/request", { mediaType: "tv", mediaId: id, seasons: "all" }, "create", function(data) {
            if (data)
                requests = [data].concat(requests)
            requestSucceeded(id, data)
            refreshRequests()
        })
    }

    function logout() {
        if (!authenticated)
            return
        _send("POST", "/auth/logout", null, "logout", function() {
            authenticated = false
            user = null
            requests = []
            searchResults = []
        })
    }
}
