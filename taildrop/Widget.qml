import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  ipcTarget: "taildrop"

  readonly property var taildrop: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property var targets: taildrop ? taildrop.targets : []
  readonly property bool sending: taildrop && taildrop.sending
  readonly property bool receiving: taildrop && taildrop.receiving
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var selectedFiles: []
  property int selectedTargetIndex: 0
  property bool cursorActive: false
  property string focusSection: "files"
  property bool reopenAfterFilePicker: false
  property string filePickerError: ""
  property bool confirmationOpen: false
  property var pendingTarget: null
  property int confirmationChoice: 0

  readonly property string filePickerSeparator: "\u001f"

  function syncServiceSettings() {
    if (taildrop && typeof taildrop.configure === "function") taildrop.configure(settings)
  }

  function selectedTarget() {
    if (targets.length === 0) return null
    return targets[Math.max(0, Math.min(selectedTargetIndex, targets.length - 1))]
  }

  function clampTargetIndex() {
    selectedTargetIndex = Math.max(0, Math.min(selectedTargetIndex, Math.max(0, targets.length - 1)))
    if (targets.length === 0 && focusSection === "targets") focusSection = "send"
  }

  function localPath(url) {
    var value = String(url || "").replace(/[\r\n]+$/, "")
    if (value.indexOf("file://") === 0) return decodeURIComponent(value.substring(7))
    return value.charAt(0) === "/" ? value : ""
  }

  function addSelectedFiles(urls) {
    var files = selectedFiles.slice()
    var seen = {}
    for (var existing = 0; existing < files.length; existing++) seen[files[existing]] = true
    var values = urls && typeof urls.length === "number" ? urls : []
    for (var i = 0; i < values.length; i++) {
      var path = localPath(values[i])
      if (path !== "" && !seen[path]) {
        files.push(path)
        seen[path] = true
      }
    }
    selectedFiles = files
  }

  function clearSelectedFiles() {
    selectedFiles = []
  }

  function chooseFiles() {
    if (sending || receiving || filePicker.running) return
    filePickerError = ""
    reopenAfterFilePicker = opened
    if (opened) close()
    filePickerOutput = ""
    filePickerErrorOutput = ""
    filePicker.command = [
      "zenity",
      "--file-selection",
      "--multiple",
      "--separator=" + filePickerSeparator,
      "--title=" + qsTr("Choose files to send with Taildrop")
    ]
    filePicker.running = true
    console.info("taildrop: opening file picker")
  }

  function finishFilePicker() {
    if (!reopenAfterFilePicker) return
    reopenAfterFilePicker = false
    open()
  }

  function moveCursor(dx, dy) {
    if (dy === 0) return
    cursorActive = true
    clampTargetIndex()

    if (dy > 0) {
      if (focusSection === "files") focusSection = targets.length > 0 ? "targets" : "send"
      else if (focusSection === "targets" && selectedTargetIndex < targets.length - 1) selectedTargetIndex++
      else if (focusSection === "targets") focusSection = "send"
      else focusSection = "files"
    } else {
      if (focusSection === "send") focusSection = targets.length > 0 ? "targets" : "files"
      else if (focusSection === "targets" && selectedTargetIndex > 0) selectedTargetIndex--
      else if (focusSection === "targets") focusSection = "files"
      else focusSection = "send"
    }
  }

  function activateCursor() {
    if (focusSection === "files") chooseFiles()
    else if (focusSection === "targets") requestSend(selectedTarget())
    else sendSelected()
  }

  function requestSend(target) {
    if (!taildrop || sending || receiving) return
    if (selectedFiles.length === 0) {
      chooseFiles()
      return
    }
    if (!target) {
      taildrop.refreshTargets()
      return
    }
    pendingTarget = target
    confirmationChoice = 0
    confirmationOpen = true
    Qt.callLater(function() { confirmation.forceActiveFocus() })
  }

  function sendSelected() {
    requestSend(selectedTarget())
  }

  function cancelConfirmation() {
    confirmationOpen = false
    pendingTarget = null
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmSend() {
    var target = pendingTarget
    confirmationOpen = false
    pendingTarget = null
    if (target) taildrop.send(selectedFiles, target)
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function handleConfirmationKey(event) {
    if (event.key === Qt.Key_Escape || event.text === "n" || event.text === "N") {
      cancelConfirmation()
    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.text === "h" || event.text === "l") {
      confirmationChoice = confirmationChoice === 0 ? 1 : 0
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.text === "y" || event.text === "Y") {
      if (confirmationChoice === 1 || event.text === "y" || event.text === "Y") confirmSend()
      else cancelConfirmation()
    } else {
      return
    }
    event.accepted = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onTaildropChanged: syncServiceSettings()
  onSettingsChanged: syncServiceSettings()
  onTargetsChanged: clampTargetIndex()
  onOpenedChanged: {
    if (!opened) {
      confirmationOpen = false
      pendingTarget = null
      return
    }
    cursorActive = false
    focusSection = "files"
    syncServiceSettings()
    if (taildrop) taildrop.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰖌"
    active: root.sending || root.receiving
    keepSpace: true
    tooltipText: root.sending ? qsTr("Taildrop transfer in progress") : qsTr("Send files with Taildrop")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) {
        if (root.taildrop) root.taildrop.refreshTargets()
      } else if (buttonCode === Qt.RightButton) {
        root.chooseFiles()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.confirmationOpen
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onDeleteRequested: if (!root.sending && !root.receiving) root.clearSelectedFiles()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "f" || text === "F") root.chooseFiles()
        else if ((text === "r" || text === "R") && root.taildrop) root.taildrop.refreshTargets()
        else if ((text === "a" || text === "A") && root.taildrop && root.taildrop.needsAuthorization) root.taildrop.authorize()
        else if ((text === "i" || text === "I") && root.taildrop && !root.sending && !root.receiving) root.taildrop.receive()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Item {
          width: parent.width
          implicitHeight: title.implicitHeight

          Text {
            id: title
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Taildrop")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          PanelActionButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            iconText: "R"
            tooltipText: qsTr("Refresh destinations")
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: root.taildrop && !root.taildrop.refreshing && !root.sending && !root.receiving
            onClicked: root.taildrop.refreshTargets()
          }
        }

        Text {
          width: parent.width
          text: root.taildrop ? root.taildrop.statusText : qsTr("Starting Taildrop...")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.taildrop && root.taildrop.lastError !== ""
          width: parent.width
          text: root.taildrop ? root.taildrop.lastError : ""
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.filePickerError !== ""
          width: parent.width
          text: root.filePickerError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ActionRow {
          visible: root.taildrop && root.taildrop.needsAuthorization
          width: parent.width
          section: "authorize"
          label: qsTr("Authorize Taildrop")
          detail: qsTr("Allow this user to send files without sudo")
          enabled: root.taildrop && !root.taildrop.sending && !root.receiving
          onActivated: root.taildrop.authorize()
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        ActionRow {
          width: parent.width
          section: "receive"
          label: root.receiving ? qsTr("Receiving incoming files...") : qsTr("Receive incoming files")
          detail: qsTr("Save Taildrop inbox files to Downloads")
          current: root.receiving
          enabled: root.taildrop && root.taildrop.installed && !root.sending && !root.receiving
          onActivated: root.taildrop.receive()
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        ActionRow {
          width: parent.width
          section: "files"
          label: root.selectedFiles.length > 0 ? qsTr("Add files") : qsTr("Choose files")
          detail: root.selectedFiles.length > 0 ? Model.fileSummary(root.selectedFiles) : qsTr("Select one or more files to send")
          selected: root.cursorActive && root.focusSection === "files"
          current: root.selectedFiles.length > 0
          enabled: !root.sending && !root.receiving
          onActivated: root.chooseFiles()
        }

        ActionRow {
          visible: root.selectedFiles.length > 0
          width: parent.width
          section: "files"
          label: qsTr("Clear file list")
          detail: qsTr("Remove all selected files")
          enabled: !root.sending && !root.receiving
          onActivated: root.clearSelectedFiles()
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Text {
          width: parent.width
          text: qsTr("DESTINATIONS")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          visible: root.taildrop && root.taildrop.installed && !root.taildrop.refreshing && root.targets.length === 0 && root.taildrop.lastError === ""
          width: parent.width
          text: qsTr("No eligible personal devices found.")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Flickable {
          id: targetsFlick
          visible: root.targets.length > 0
          width: parent.width
          implicitHeight: Math.min(targetColumn.implicitHeight, Style.space(250))
          height: implicitHeight
          contentWidth: width
          contentHeight: targetColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick

          Column {
            id: targetColumn
            width: targetsFlick.width
            spacing: Style.space(6)

            Repeater {
              model: root.targets

              TargetRow {
                required property var modelData
                required property int index
                width: targetColumn.width
                target: modelData
                rowIndex: index
              }
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        ActionRow {
          width: parent.width
          section: "send"
          label: root.sending ? qsTr("Cancel transfer") : qsTr("Send selected files")
          detail: root.sending
            ? (root.taildrop && root.taildrop.canceling ? qsTr("Canceling...") : qsTr("Stop the active transfer"))
            : (root.selectedTarget() ? qsTr("Send to %1").arg(root.selectedTarget().displayName) : qsTr("Select a destination first"))
          selected: root.cursorActive && root.focusSection === "send"
          current: root.sending
          enabled: root.taildrop && root.taildrop.installed && !root.receiving && (!root.sending || !root.taildrop.canceling)
          onActivated: {
            if (root.sending) root.taildrop.cancel()
            else root.sendSelected()
          }
        }
      }
    }

    BorderSurface {
      id: confirmation
      anchors.fill: parent
      visible: root.confirmationOpen
      z: 1
      color: Color.popups.background
      borderSpec: Border.controlSpec("focus", root.foreground, Color.accent)
      radius: Style.cornerRadius
      focus: visible

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) { root.handleConfirmationKey(event) }

      Column {
        anchors.centerIn: parent
        width: parent.width - Style.space(20)
        spacing: Style.space(12)

        Text {
          width: parent.width
          text: root.pendingTarget
            ? qsTr("Send %1 to %2?").arg(root.selectedFiles.length === 1
              ? Model.fileName(root.selectedFiles[0])
              : qsTr("%1 files").arg(root.selectedFiles.length)).arg(root.pendingTarget.displayName)
            : qsTr("Send selected files?")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          text: qsTr("The files will be sent with Taildrop.")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          ConfirmationChoice {
            width: (parent.width - parent.spacing) / 2
            choiceIndex: 0
            label: qsTr("No")
            selected: root.confirmationChoice === 0
            onChosen: root.cancelConfirmation()
          }

          ConfirmationChoice {
            width: (parent.width - parent.spacing) / 2
            choiceIndex: 1
            label: qsTr("Yes, send")
            selected: root.confirmationChoice === 1
            onChosen: root.confirmSend()
          }
        }
      }
    }
  }

  property string filePickerOutput: ""
  property string filePickerErrorOutput: ""

  Process {
    id: filePicker
    running: false
    command: []
    stdout: StdioCollector {
      id: filePickerStdout
      waitForEnd: true
      onStreamFinished: root.filePickerOutput = text
    }
    stderr: StdioCollector {
      id: filePickerStderr
      waitForEnd: true
      onStreamFinished: root.filePickerErrorOutput = text
    }
    onExited: function(exitCode) {
      var stdout = String(filePickerStdout.text || root.filePickerOutput || "")
      var stderr = String(filePickerStderr.text || root.filePickerErrorOutput || "").replace(/\s+/g, " ").trim()
      if (exitCode === 0) {
        var selectedBefore = root.selectedFiles.length
        root.addSelectedFiles(stdout.split(root.filePickerSeparator))
        console.info("taildrop: added " + (root.selectedFiles.length - selectedBefore) + " file(s), " + root.selectedFiles.length + " total")
      } else if (exitCode === 1) {
        console.info("taildrop: file picker canceled")
      } else {
        root.filePickerError = stderr || qsTr("Could not open the file picker")
        console.warn("taildrop: file picker failed: " + root.filePickerError)
      }
      root.finishFilePicker()
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow

    property string label: ""
    property string detail: ""
    property string section: ""
    property bool selected: false
    signal activated()

    enabled: true
    hasCursor: selected
    foreground: root.foreground
    implicitHeight: row.implicitHeight + Style.spacing.rowPaddingX

    Row {
      id: row
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Column {
        width: parent.width
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: actionRow.label
          color: actionRow.enabled ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: actionRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: actionRow.enabled
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = actionRow.section
      }
      onClicked: actionRow.activated()
    }
  }

  component TargetRow: CursorSurface {
    id: targetRow

    property var target: null
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.focusSection === "targets" && root.selectedTargetIndex === rowIndex
    current: root.selectedTargetIndex === rowIndex
    foreground: root.foreground
    implicitHeight: row.implicitHeight + Style.spacing.rowPaddingX

    Row {
      id: row
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Column {
        width: parent.width
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: targetRow.target ? targetRow.target.displayName : qsTr("Unknown device")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: {
            if (!targetRow.target) return ""
            return targetRow.target.detail !== "" ? targetRow.target.address + " | " + targetRow.target.detail : targetRow.target.address
          }
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: !root.sending && !root.receiving
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = "targets"
        root.selectedTargetIndex = targetRow.rowIndex
      }
      onClicked: {
        root.selectedTargetIndex = targetRow.rowIndex
        root.requestSend(targetRow.target)
      }
    }
  }

  component ConfirmationChoice: CursorSurface {
    id: choice

    property string label: ""
    property int choiceIndex: 0
    property bool selected: false
    signal chosen()

    hasCursor: selected
    foreground: root.foreground
    implicitHeight: Style.space(42)

    Text {
      anchors.centerIn: parent
      text: choice.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.confirmationChoice = choice.choiceIndex
      onClicked: choice.chosen()
    }
  }
}
