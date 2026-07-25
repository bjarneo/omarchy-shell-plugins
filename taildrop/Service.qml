import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var settings: ({})

  property bool installed: false
  property bool refreshing: false
  property bool sending: false
  property bool receiving: false
  property bool canceling: false
  property bool needsAuthorization: false
  property string statusText: qsTr("Checking Taildrop...")
  property string lastError: ""
  property var targets: []
  property string transferTargetName: ""
  property int transferFileCount: 0

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 30, 5, 3600)
  readonly property bool notifyOnComplete: boolSetting("notifyOnComplete", true)
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME")
  readonly property string receiveDirectory: Quickshell.env("HOME") + "/Downloads"

  property string _targetsOutput: ""
  property string _targetsError: ""
  property string _sendOutput: ""
  property string _sendError: ""
  property string _authorizationOutput: ""
  property string _authorizationError: ""
  property string _receiveOutput: ""
  property string _receiveError: ""

  function configure(nextSettings) {
    settings = nextSettings || ({})
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value)) value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    return value === true || value === "true"
  }

  function refresh() {
    if (installed) {
      refreshTargets()
      return
    }
    if (whichProcess.running) return
    refreshing = true
    statusText = qsTr("Checking Taildrop...")
    whichProcess.command = ["which", "tailscale"]
    whichProcess.running = true
  }

  function refreshTargets() {
    if (!installed || targetsProcess.running) return
    _targetsOutput = ""
    _targetsError = ""
    refreshing = true
    targetsProcess.command = ["tailscale", "file", "cp", "--targets"]
    targetsProcess.running = true
  }

  function send(files, target) {
    if (!installed || sending || receiving || sendProcess.running) return false

    var selectedFiles = []
    var values = files && typeof files.length === "number" ? files : []
    for (var i = 0; i < values.length; i++) {
      var path = String(values[i] || "")
      if (path !== "") selectedFiles.push(path)
    }

    var destination = Model.targetArgument(target)
    if (selectedFiles.length === 0 || destination === "") return false

    _sendOutput = ""
    _sendError = ""
    sending = true
    transferFileCount = selectedFiles.length
    transferTargetName = String(target.displayName || target.name || target.address || "")
    lastError = ""
    statusText = qsTr("Sending %1...").arg(Model.fileSummary(selectedFiles))
    console.info("taildrop: sending " + selectedFiles.length + " file(s) to " + transferTargetName)
    sendProcess.command = ["tailscale", "file", "cp", "--update-interval=0s"]
      .concat(selectedFiles)
      .concat([destination])
    sendProcess.running = true
    return true
  }

  function authorize() {
    if (!installed || userName === "" || authorizationProcess.running) return
    _authorizationOutput = ""
    _authorizationError = ""
    statusText = qsTr("Authorizing Taildrop...")
    authorizationProcess.command = ["pkexec", "tailscale", "set", "--operator=" + userName]
    authorizationProcess.running = true
  }

  function cancel() {
    if (!sendProcess.running || canceling) return
    canceling = true
    statusText = qsTr("Canceling transfer...")
    sendProcess.running = false
  }

  function receive() {
    if (!installed || sending || receiving || receiveProcess.running) return false
    _receiveOutput = ""
    _receiveError = ""
    receiving = true
    lastError = ""
    statusText = qsTr("Receiving incoming files...")
    receiveProcess.command = ["tailscale", "file", "get", "--conflict=rename", "--verbose", receiveDirectory]
    receiveProcess.running = true
    console.info("taildrop: checking incoming files")
    return true
  }

  function isAuthorizationFailure(detail) {
    return /file access denied/i.test(String(detail || ""))
  }

  function notificationProgram() {
    return omarchyPath ? omarchyPath + "/bin/omarchy-notification-send" : "omarchy-notification-send"
  }

  function notify(title, description) {
    Quickshell.execDetached([notificationProgram(), title, description])
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: delayedRefresh
    interval: 600
    repeat: false
    onTriggered: root.refreshTargets()
  }

  Process {
    id: whichProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) {
        root.refreshTargets()
      } else {
        root.refreshing = false
        root.targets = []
        root.statusText = qsTr("Tailscale CLI is not installed")
        root.lastError = ""
      }
    }
  }

  Process {
    id: targetsProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: targetsStdout
      waitForEnd: true
      onStreamFinished: root._targetsOutput = text
    }
    stderr: StdioCollector {
      id: targetsStderr
      waitForEnd: true
      onStreamFinished: root._targetsError = text
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var stdout = String(targetsStdout.text || root._targetsOutput || "")
      var stderr = String(targetsStderr.text || root._targetsError || "")
      if (exitCode !== 0) {
        root.targets = []
        root.statusText = qsTr("Taildrop is unavailable")
        root.lastError = Model.elideStatus(stderr || stdout || qsTr("Could not list Taildrop destinations"))
        return
      }

      root.targets = Model.parseTargets(stdout)
      root.lastError = ""
      root.statusText = root.targets.length === 0
        ? qsTr("No eligible devices found")
        : qsTr("%1 devices ready").arg(root.targets.length)
    }
  }

  Process {
    id: sendProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: sendStdout
      waitForEnd: true
      onStreamFinished: root._sendOutput = text
    }
    stderr: StdioCollector {
      id: sendStderr
      waitForEnd: true
      onStreamFinished: root._sendError = text
    }
    onExited: function(exitCode) {
      var stdout = String(sendStdout.text || root._sendOutput || "")
      var stderr = String(sendStderr.text || root._sendError || "")
      var summary = root.transferFileCount === 1
        ? qsTr("1 file")
        : qsTr("%1 files").arg(root.transferFileCount)
      root.sending = false

      if (root.canceling) {
        root.canceling = false
        root.statusText = qsTr("Transfer canceled")
        root.lastError = ""
        console.info("taildrop: transfer canceled")
      } else if (exitCode === 0) {
        root.statusText = qsTr("Sent %1 to %2").arg(summary).arg(root.transferTargetName)
        root.lastError = ""
        root.needsAuthorization = false
        console.info("taildrop: sent " + summary + " to " + root.transferTargetName)
        if (root.notifyOnComplete) root.notify(qsTr("Taildrop sent"), root.statusText)
      } else {
        var detail = Model.elideStatus(stderr || stdout || qsTr("Taildrop could not send the selected files"))
        root.needsAuthorization = root.isAuthorizationFailure(detail)
        root.statusText = root.needsAuthorization
          ? qsTr("Taildrop authorization required")
          : qsTr("Transfer failed")
        root.lastError = ""
        console.warn("taildrop: transfer failed: " + detail)
        root.notify(qsTr("Taildrop failed"), root.statusText)
      }

      root.transferFileCount = 0
      root.transferTargetName = ""
      delayedRefresh.restart()
    }
  }

  Process {
    id: receiveProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: receiveStdout
      waitForEnd: true
      onStreamFinished: root._receiveOutput = text
    }
    stderr: StdioCollector {
      id: receiveStderr
      waitForEnd: true
      onStreamFinished: root._receiveError = text
    }
    onExited: function(exitCode) {
      var stdout = String(receiveStdout.text || root._receiveOutput || "")
      var stderr = String(receiveStderr.text || root._receiveError || "")
      root.receiving = false
      if (exitCode === 0) {
        var count = Model.receivedFileCount(stdout)
        root.needsAuthorization = false
        root.statusText = count === 0
          ? qsTr("No incoming files")
          : (count === 1 ? qsTr("Received 1 file") : qsTr("Received %1 files").arg(count))
        root.lastError = ""
        console.info("taildrop: received " + count + " file(s)")
        if (count > 0 && root.notifyOnComplete) root.notify(qsTr("Taildrop received"), root.statusText)
      } else {
        var detail = Model.elideStatus(stderr || stdout || qsTr("Taildrop could not receive incoming files"))
        root.needsAuthorization = root.isAuthorizationFailure(detail)
        root.statusText = root.needsAuthorization
          ? qsTr("Taildrop authorization required")
          : qsTr("Receive failed")
        root.lastError = ""
        console.warn("taildrop: receive failed: " + detail)
      }
    }
  }

  Process {
    id: authorizationProcess
    running: false
    command: []
    stdout: StdioCollector {
      id: authorizationStdout
      waitForEnd: true
      onStreamFinished: root._authorizationOutput = text
    }
    stderr: StdioCollector {
      id: authorizationStderr
      waitForEnd: true
      onStreamFinished: root._authorizationError = text
    }
    onExited: function(exitCode) {
      var stdout = String(authorizationStdout.text || root._authorizationOutput || "")
      var stderr = String(authorizationStderr.text || root._authorizationError || "")
      if (exitCode === 0) {
        root.needsAuthorization = false
        root.statusText = qsTr("Taildrop authorized")
        root.lastError = ""
        console.info("taildrop: authorization granted")
      } else {
        root.statusText = qsTr("Taildrop authorization required")
        root.lastError = ""
        console.warn("taildrop: authorization failed: " + Model.elideStatus(stderr || stdout || "Authorization canceled"))
      }
    }
  }
}
