import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.omarchy-seerr.plugin"
  ipcTarget: ""
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property alias api: seerrApi
  property bool showSettings: false
  property string searchText: ""

  readonly property int widthHint: Style.space(440)
  readonly property string fontFamily: Style.font.family

  function open() {
    controller.show()
    if (seerrApi.authenticated) seerrApi.refreshRequests()
    else seerrApi.restore()
    Qt.callLater(function() { if (opened) keyCatcher.forceActiveFocus() })
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  function closeForPopoutSwitch() {
    popoutSwitchClosing = true
    close()
    Qt.callLater(function() { popoutSwitchClosing = false })
  }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }

  function submitSearch() {
    var query = searchField.text.trim()
    searchText = query
    seerrApi.searchResults = []
    if (query.length > 0) seerrApi.search(query)
  }

  function isRequested(result) {
    var id = Number(result && (result.id || result.tmdbId))
    if (!id || !seerrApi.requests) return false
    for (var i = 0; i < seerrApi.requests.length; i++) {
      var media = seerrApi.requests[i].mediaInfo || seerrApi.requests[i].media || {}
      if (Number(media.tmdbId || media.id) === id) return true
    }
    return false
  }

  function mediaStatusLabel(status) {
    switch (Number(status)) {
    case 5: return "Available / downloaded"
    case 4: return "Partially available"
    case 3: return "Processing"
    case 2: return "Pending"
    case 1: return "Unknown"
    case 6: return "Unavailable"
    default: return "Not requested"
    }
  }
  function requestStatusLabel(request) {
    return mediaStatusLabel((request && (request.mediaInfo || request.media || {}).status) || 0)
  }


  SeerrApi { id: seerrApi }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(root.widthHint)
    contentHeight: fittedContentHeight(panelContent.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: loginUrl.activeFocus || emailField.activeFocus || passwordField.activeFocus || searchField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: panelContent
          width: parent.width
          spacing: Style.spacing.md

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: seerrApi.authenticated ? "TV REQUESTS" : "SEERR SETUP"
              color: Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
              Layout.fillWidth: true
            }
            Button {
              visible: seerrApi.authenticated
              text: "Refresh"
              fontSize: Style.font.bodySmall
              onClicked: seerrApi.refreshRequests()
            }
            Button {
              visible: seerrApi.authenticated
              text: "Settings"
              fontSize: Style.font.bodySmall
              selected: root.showSettings
              onClicked: root.showSettings = !root.showSettings
            }
          }
          Text {
            visible: root.showSettings && seerrApi.authenticated
            text: "Signed in" + (seerrApi.user && seerrApi.user.email ? " as " + seerrApi.user.email : "")
              + ". Session lasts only while the shell is running; sign in again after a restart. Use HTTPS remotely."
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }
          Button {
            visible: root.showSettings && seerrApi.authenticated
            text: "Sign out"
            fontSize: Style.font.bodySmall
            onClicked: { seerrApi.logout(); root.showSettings = false }
          }

          ColumnLayout {
            visible: !seerrApi.authenticated
            Layout.fillWidth: true
            spacing: Style.spacing.md
            Text {
              text: "Connect to your Seerr server to browse and request TV shows."
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            TextField {
              id: loginUrl
              Layout.fillWidth: true
              placeholderText: "Server URL (https://seerr.example)"
              text: seerrApi.serverUrl
              onTextChanged: if (!activeFocus && text !== seerrApi.serverUrl) text = seerrApi.serverUrl
            }
            TextField {
              id: emailField
              Layout.fillWidth: true
              placeholderText: "Email"
              inputMethodHints: Qt.ImhEmailCharactersOnly
            }
            TextField {
              id: passwordField
              Layout.fillWidth: true
              placeholderText: "Password"
              echoMode: TextInput.Password
              Keys.onReturnPressed: loginButton.clicked()
              Keys.onEnterPressed: loginButton.clicked()
            }
            Button {
              id: loginButton
              Layout.fillWidth: true
              text: seerrApi.busy ? "Signing in…" : "Sign in"
              enabled: !seerrApi.busy && loginUrl.text.trim() !== "" && emailField.text.trim() !== "" && passwordField.text !== ""
              onClicked: {
                seerrApi.login(loginUrl.text.trim(), emailField.text.trim(), passwordField.text)
                passwordField.text = ""
              }
            }
          }

          Text {
            visible: seerrApi.error !== ""
            text: seerrApi.error
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          RowLayout {
            visible: seerrApi.authenticated && !root.showSettings
            Layout.fillWidth: true
            TextField {
              id: searchField
              Layout.fillWidth: true
              placeholderText: "Search TV shows"
              onTextChanged: searchDebounce.restart()
              Keys.onReturnPressed: root.submitSearch()
              Keys.onEnterPressed: root.submitSearch()
            }
            Button {
              text: "Search"
              enabled: searchField.text.trim() !== ""
              onClicked: root.submitSearch()
            }
          }
          Timer {
            id: searchDebounce
            interval: 350
            onTriggered: root.submitSearch()
          }


          Text {
            visible: seerrApi.busy && (!seerrApi.authenticated || seerrApi.requests.length === 0)
            text: "Loading…"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          Text {
            visible: seerrApi.authenticated && !root.showSettings && root.searchText === "" && !seerrApi.busy && seerrApi.requests.length === 0 && seerrApi.error === ""
            text: "No TV requests yet. Search for a show to get started."
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }

          Repeater {
            model: seerrApi.authenticated && !root.showSettings && root.searchText === "" ? seerrApi.requests : []
            delegate: showRow
          }

          Text {
            visible: seerrApi.authenticated && !root.showSettings && root.searchText !== ""
            text: seerrApi.busy ? "Loading…" : "Search results"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.fillWidth: true
          }
          Text {
            visible: seerrApi.authenticated && !root.showSettings && root.searchText !== "" && seerrApi.searchResults.length === 0 && !seerrApi.busy && seerrApi.error === ""
            text: "No TV shows found."
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }
          Repeater {
            model: seerrApi.authenticated && !root.showSettings && root.searchText !== "" ? seerrApi.searchResults : []
            delegate: searchRow
          }
        }
      }
    }
  }

  Component {
    id: showRow
    RowLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.spacing.md
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs
        Text {
          text: modelData.title || modelData.name || (modelData.mediaInfo || modelData.media || {}).title || (modelData.mediaInfo || modelData.media || {}).name || ((modelData.mediaInfo || modelData.media || {}).tmdbId ? "TV show #" + (modelData.mediaInfo || modelData.media || {}).tmdbId : "TV show")
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: root.requestStatusLabel(modelData)
          color: Number((modelData.mediaInfo || modelData.media || {}).status) === 5 ? Color.accent : Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  Component {
    id: searchRow
    RowLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.spacing.md
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs
        Text {
          text: modelData.name || modelData.title || "Untitled"
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: {
            var media = modelData.mediaInfo || modelData.media || {}
            return root.isRequested(modelData) ? "Already requested · " + root.mediaStatusLabel(media.status)
              : (modelData.firstAirDate ? String(modelData.firstAirDate).slice(0, 4) : "TV show")
          }
          color: root.isRequested(modelData) && Number((modelData.mediaInfo || modelData.media || {}).status) === 5 ? Color.accent : Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
      Button {
        text: root.isRequested(modelData) ? root.mediaStatusLabel((modelData.mediaInfo || modelData.media || {}).status) : (seerrApi.busy ? "…" : (Number((modelData.mediaInfo || modelData.media || {}).status || 0) >= 2 ? root.mediaStatusLabel((modelData.mediaInfo || modelData.media || {}).status) : "Request"))
        enabled: !root.isRequested(modelData) && !seerrApi.busy && Number((modelData.mediaInfo || modelData.media || {}).status || 0) < 2
        onClicked: seerrApi.requestShow(Number(modelData.id))
      }
    }
  }

  onOpenedChanged: {
    if (!opened) return
    Qt.callLater(function() { if (opened) keyCatcher.forceActiveFocus() })
  }
}
