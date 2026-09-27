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
  property bool sendingKey: false
  property bool showSettings: false
  property bool popoutSwitchClosing: false
  property string searchText: ""
  property int selectedResultIndex: -1
  property int deletingRequestId: 0
  property int seasonPickerTmdbId: 0
  property var seasonPickerOptions: []
  property var seasonPickerSelected: []

  property bool focusResults: false

  function requestResult(result) {
    var type = root.resultType(result)
    var id = Number(result.id || result.tmdbId)
    if (type !== "tv") { seerrApi.requestMedia(type, id); return }
    seerrApi.fetchTvSeasons(id, function(seasons) {
      if (!seasons.length) { seerrApi.requestMedia("tv", id, ["all"]); return }
      root.seasonPickerTmdbId = id
      root.seasonPickerOptions = seasons
      root.seasonPickerSelected = seasons.filter(function(s) { return s.available })
                                         .map(function(s) { return s.seasonNumber })
    })
  }
  function seasonSelected(seasonNumber) {
    return root.seasonPickerSelected.indexOf(seasonNumber) >= 0
  }
  function toggleSeason(seasonNumber) {
    var idx = root.seasonPickerSelected.indexOf(seasonNumber)
    if (idx >= 0) root.seasonPickerSelected.splice(idx, 1)
    else root.seasonPickerSelected.push(seasonNumber)
    root.seasonPickerSelected = root.seasonPickerSelected.slice()
  }
  function selectSeasonRange(mode) {
    if (!root.seasonPickerOptions.length) return
    if (mode === "all") {
      root.seasonPickerSelected = root.seasonPickerOptions.map(function(s) { return s.seasonNumber })
    } else if (mode === "first") {
      root.seasonPickerSelected = [root.seasonPickerOptions[0].seasonNumber]
    } else if (mode === "latest") {
      root.seasonPickerSelected = [root.seasonPickerOptions[root.seasonPickerOptions.length - 1].seasonNumber]
    }
  }

  readonly property int widthHint: Style.space(440)
  readonly property string fontFamily: Style.font.family

  function open() {
    controller.show()
    if (seerrApi.authenticated) {
      searchField.text = ""
      searchText = ""
      seerrApi.searchResults = []
      seerrApi.refreshRequests()
    } else seerrApi.restore()
    Qt.callLater(function() {
      if (opened && seerrApi.authenticated && !showSettings) searchField.forceActiveFocus()
    })
  }
  function resultType(result) { return String(result.mediaType || "tv").toLowerCase() }
  function resultTitle(result) { return result.title || result.name || "Untitled" }
  function resultYear(result) { return String(result.year || result.releaseDate || result.firstAirDate || "").slice(0, 4) }
  function requestTitle(request) { return request.title || request.name || "Untitled" }
  function requestYear(request) { return String(request.year || request.releaseDate || request.firstAirDate || "").slice(0, 4) }
  function moveResultSelection(delta) {
    if (!seerrApi.searchResults || seerrApi.searchResults.length === 0) return
    focusResults = true
    var next = selectedResultIndex < 0 ? 0 : selectedResultIndex + delta
    selectedResultIndex = Math.max(0, Math.min(seerrApi.searchResults.length - 1, next))
    Qt.callLater(function() { var item = resultButtons.itemAt(selectedResultIndex); if (item && item.requestButton) item.requestButton.forceActiveFocus() })
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


  function mediaStatusLabel(status) {
    switch (Number(status)) {
    case 5: return "Available"
    case 4: return "Partially available"
    case 3: return "Processing"
    case 2: return "Pending"
    case 1: return "Unknown"
    case 6: return "Unavailable"
    default: return "Requested"
    }
  }
  function requestStatusLabel(request) { return request.statusLabel || mediaStatusLabel((request && (request.mediaInfo || request.media || {}).status) || 0) }


  Connections {
    target: seerrApi
    function onAuthenticatedChanged() {
      if (seerrApi.authenticated && root.opened && !root.showSettings)
        Qt.callLater(function() { if (root.opened && !root.showSettings) searchField.forceActiveFocus() })
    }
    function onKeyVerificationFinished(result) { root.sendingKey = false }
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
      blocked: loginUrl.activeFocus || apiKeyField.activeFocus || searchField.activeFocus || root.deletingRequestId !== 0 || root.seasonPickerTmdbId !== 0
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ConfirmDialog {
        anchors.fill: parent
        z: 20
        focus: true
        opened: root.deletingRequestId !== 0
        message: "Remove this request from Seerr? This does not delete downloaded files."
        cancelText: "Cancel"
        confirmText: "Remove"
        onOpenedChanged: if (opened) forceActiveFocus()
        Keys.onPressed: function(event) { if (handleKey(event)) event.accepted = true }
        onCanceled: {
          root.deletingRequestId = 0
          Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
        }
        onConfirmed: {
          seerrApi.deleteRequest(root.deletingRequestId)
          root.deletingRequestId = 0
          Qt.callLater(function() { if (root.opened) keyCatcher.forceActiveFocus() })
        }
      }

      BorderSurface {
        anchors.fill: parent
        z: 20
        visible: root.seasonPickerTmdbId !== 0
        color: Color.popups.background
        borderSpec: Border.none()

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.spacing.md
          spacing: Style.spacing.md

          Text {
            text: "Request seasons"
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            Layout.fillWidth: true
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm
            Button {
              Layout.fillWidth: true
              text: "First"
              onClicked: root.selectSeasonRange("first")
            }
            Button {
              Layout.fillWidth: true
              text: "Latest"
              onClicked: root.selectSeasonRange("latest")
            }
            Button {
              Layout.fillWidth: true
              text: "All"
              onClicked: root.selectSeasonRange("all")
            }
          }

          Text {
            text: "Choose:"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: seasonToggleColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: true

            ColumnLayout {
              id: seasonToggleColumn
              width: parent.width
              spacing: Style.spacing.sm

              Repeater {
                model: root.seasonPickerOptions
                delegate: Toggle {
                  required property var modelData
                  Layout.fillWidth: true
                  label: modelData.name || ("Season " + modelData.seasonNumber)
                  checked: root.seasonSelected(modelData.seasonNumber)
                  onClicked: root.toggleSeason(modelData.seasonNumber)
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm
            Button {
              Layout.fillWidth: true
              text: "Cancel"
              onClicked: {
                root.seasonPickerTmdbId = 0
                root.seasonPickerOptions = []
                root.seasonPickerSelected = []
              }
            }
            Button {
              Layout.fillWidth: true
              text: "Request"
              enabled: root.seasonPickerSelected.length > 0
              onClicked: {
                seerrApi.requestMedia("tv", root.seasonPickerTmdbId, root.seasonPickerSelected)
                root.seasonPickerTmdbId = 0
                root.seasonPickerOptions = []
                root.seasonPickerSelected = []
              }
            }
          }
        }
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: true

        ColumnLayout {
          id: panelContent
          width: parent.width
          spacing: Style.spacing.md

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: seerrApi.authenticated ? "Seerr Requests" : "SEERR SETUP"
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
            visible: root.showSettings && seerrApi.authenticated && seerrApi.authMode === "keyring"
            text: "API key is saved in the desktop keyring. Unlock your login keyring after reboot."
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
          }
          Dropdown {
            visible: root.showSettings && seerrApi.authenticated && seerrApi.movieProfiles.length > 0
            Layout.fillWidth: true
            label: "Movie quality profile"
            value: String(seerrApi.movieProfileId)
            options: seerrApi.movieProfiles
            onChanged: seerrApi.setMovieProfile(value)
          }
          Dropdown {
            visible: root.showSettings && seerrApi.authenticated && seerrApi.tvProfiles.length > 0
            Layout.fillWidth: true
            label: "TV quality profile"
            value: String(seerrApi.tvProfileId)
            options: seerrApi.tvProfiles
            onChanged: seerrApi.setTvProfile(value)
          }
          Text {
            visible: root.showSettings && seerrApi.authenticated && seerrApi.movieProfiles.length === 0 && seerrApi.tvProfiles.length === 0 && !seerrApi.busy
            text: "Quality profiles unavailable. In Seerr → Settings → General → API Key, make sure this key has the Settings permission."
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
            foreground: Color.urgent
            onClicked: { seerrApi.logout(); apiKeyField.text = ""; root.showSettings = false }
          }

          ColumnLayout {
            visible: !seerrApi.authenticated && !seerrApi.awaitingKeyStorageChoice
            Layout.fillWidth: true
            spacing: Style.spacing.md
            Text {
              text: "Sign in with a Seerr API key."
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
              id: apiKeyField
              Layout.fillWidth: true
              placeholderText: "Seerr API key"
              password: true
              Keys.onReturnPressed: loginButton.clicked()
              Keys.onEnterPressed: loginButton.clicked()
            }
            Button {
              id: loginButton
              Layout.fillWidth: true
              text: root.sendingKey ? "Signing in…" : "Sign in"
              enabled: !root.sendingKey && !seerrApi.busy && loginUrl.text.trim() !== "" && apiKeyField.text.trim() !== ""
              onClicked: {
                root.sendingKey = true
                seerrApi.loginWithApiKey(loginUrl.text.trim(), apiKeyField.text)
                apiKeyField.text = ""
              }
            }
            Text {
              text: "Create an API key in Seerr Settings → General. It grants broad server API access and will be saved in your unlocked desktop keyring."
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            Text {
              text: "Seerr API key documentation ↗"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.underline: true
              Layout.fillWidth: true
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally("https://docs.seerr.dev/api/seerr-api/")
              }
            }
          }

          ColumnLayout {
            visible: seerrApi.awaitingKeyStorageChoice
            onVisibleChanged: if (visible) root.sendingKey = false
            Layout.fillWidth: true
            spacing: Style.spacing.md
            Text {
              text: "Signed in as " + (seerrApi.user && seerrApi.user.displayName || seerrApi.user && seerrApi.user.username || "Seerr")
              color: Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            Text {
              text: "Save the API key in your desktop keyring, or use it only for this session?"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }
            Button {
              Layout.fillWidth: true
              text: "Save in keyring (recommended)"
              onClicked: seerrApi.chooseKeyStorage("keyring")
            }
            Button {
              Layout.fillWidth: true
              text: "Use this session only"
              onClicked: seerrApi.chooseKeyStorage("none")
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
              placeholderText: "Search TV shows and movies"
              onTextChanged: searchDebounce.restart()
              Keys.onReturnPressed: root.submitSearch()
              Keys.onEnterPressed: root.submitSearch()
              Keys.onDownPressed: { root.selectedResultIndex = -1; root.moveResultSelection(1); event.accepted = true }
              Keys.onTabPressed: function(event) {
                if (!event.modifiers && resultButtons.count > 0) { root.selectedResultIndex = -1; root.moveResultSelection(1); event.accepted = true }
              }
              Keys.onEscapePressed: { root.close(); event.accepted = true }
              onActiveFocusChanged: if (activeFocus) { root.focusResults = false; root.selectedResultIndex = -1 }
            }
            Button {
              text: "Search"
              enabled: searchField.text.trim() !== ""
              onClicked: root.submitSearch()
            }
          }
          Item { Layout.preferredHeight: Style.spacing.sm; visible: seerrApi.authenticated && !root.showSettings }
          Timer {
            id: searchDebounce
            interval: 350
            onTriggered: root.submitSearch()
          }

          Text {
            visible: seerrApi.authenticated && !root.showSettings && root.searchText === "" && !seerrApi.busy && seerrApi.requests.length === 0 && seerrApi.error === ""
            text: "No requests yet. Search for a show or movie to get started."
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
            text: "No matching TV shows or movies found."
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            Layout.fillWidth: true
          }
          Repeater {
            id: resultButtons
            model: seerrApi.authenticated && !root.showSettings && root.searchText !== "" ? seerrApi.searchResults : []
            delegate: searchRow
            onCountChanged: { root.selectedResultIndex = -1; root.focusResults = false }
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
      Item {
        Layout.preferredWidth: Style.space(48)
        Layout.preferredHeight: Style.space(72)
        Image {
          anchors.fill: parent
          source: modelData.posterUrl || ""
          visible: source.toString() !== ""
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: Style.space(48)
          sourceSize.height: Style.space(72)
        }
        Rectangle {
          anchors.fill: parent
          visible: !modelData.posterUrl
          color: Color.popups.background
          radius: Style.radius.sm
          Text { anchors.centerIn: parent; text: "▧"; color: Color.muted; font.pixelSize: Style.font.title }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs
        Text {
          text: root.requestTitle(modelData)
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: (root.requestYear(modelData) ? root.requestYear(modelData) + " · " : "") + root.resultType(modelData).toUpperCase() + " · " + root.requestStatusLabel(modelData)
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
      Button {
        text: "Remove"
        fontSize: Style.font.bodySmall
        foreground: Color.urgent
        onClicked: root.deletingRequestId = Number(modelData.requestId || 0)
      }
    }
  }

  Component {
    id: searchRow
    RowLayout {
      required property var modelData
      Layout.fillWidth: true
      spacing: Style.spacing.md
      Item {
        Layout.preferredWidth: Style.space(48)
        Layout.preferredHeight: Style.space(72)
        Image {
          anchors.fill: parent
          source: modelData.posterUrl || ""
          visible: source.toString() !== ""
          fillMode: Image.PreserveAspectCrop
          sourceSize.width: Style.space(48)
          sourceSize.height: Style.space(72)
        }
        Rectangle {
          anchors.fill: parent
          visible: !modelData.posterUrl
          color: Color.popups.background
          radius: Style.radius.sm
          Text { anchors.centerIn: parent; text: "▧"; color: Color.muted; font.pixelSize: Style.font.title }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs
        Text {
          text: root.resultTitle(modelData)
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          text: (root.resultYear(modelData) ? root.resultYear(modelData) + " · " : "") + root.resultType(modelData).toUpperCase() + " · " + root.requestStatusLabel(modelData)
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
      Button {
        id: requestButton
        property int resultIndex: index
        readonly property bool fullyAvailable: Number(modelData.status) === 5
        readonly property bool partiallyAvailable: Number(modelData.status) === 4
        selected: root.selectedResultIndex === resultIndex
        text: fullyAvailable ? "Available" : (partiallyAvailable ? "Request" : (modelData.alreadyRequested ? (modelData.statusLabel || "Requested") : (seerrApi.busy ? "…" : "Request")))
        enabled: !fullyAvailable && !seerrApi.busy && (!modelData.alreadyRequested || partiallyAvailable)
        onClicked: root.requestResult(modelData)
        Keys.onDownPressed: { root.moveResultSelection(1); event.accepted = true }
        Keys.onUpPressed: { root.moveResultSelection(-1); event.accepted = true }
        Keys.onTabPressed: function(event) {
          if (!event.modifiers) {
            if (resultIndex + 1 < resultButtons.count) root.moveResultSelection(1)
            else searchField.forceActiveFocus()
            event.accepted = true
          }
        }
        Keys.onBacktabPressed: function(event) {
          if (resultIndex > 0) root.moveResultSelection(-1)
          else searchField.forceActiveFocus()
          event.accepted = true
        }
        onActiveFocusChanged: if (activeFocus) { root.focusResults = true; root.selectedResultIndex = resultIndex }
      }
    }
  }

  onOpenedChanged: {
    if (!opened) return
    Qt.callLater(function() { if (opened && seerrApi.authenticated && !showSettings) searchField.forceActiveFocus() })
  }
}
