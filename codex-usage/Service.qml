import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property bool refreshing: false
  property string statusText: qsTr("Loading Codex usage...")
  property string lastError: ""
  property string planType: ""
  property bool limitReached: false
  property var primaryWindow: null
  property var secondaryWindow: null

  property string _usageOutput: ""
  property string _usageError: ""

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 60, 30, 3600)
  readonly property string appServerScript:
    "codex_bin=''; " +
    "for candidate in \"${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}\"/installs/codex/*/codex-*; do [ -x \"$candidate\" ] && codex_bin=\"$candidate\"; done; " +
    "[ -n \"$codex_bin\" ] || codex_bin=\"$(command -v codex 2>/dev/null || true)\"; " +
    "[ -n \"$codex_bin\" ] || { printf '%s\\n' 'Codex CLI is not installed' >&2; exit 127; }; " +
    "coproc CODEX_APP { \"$codex_bin\" app-server --stdio; }; " +
    "printf '%s\\n' '{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"omarchy-codex-usage\",\"title\":null,\"version\":\"0.1.0\"}}}' >&\"${CODEX_APP[1]}\"; " +
    "IFS= read -r initialize_response <&\"${CODEX_APP[0]}\" || exit 1; " +
    "printf '%s\\n' '{\"id\":2,\"method\":\"account/rateLimits/read\"}' >&\"${CODEX_APP[1]}\"; " +
    "while IFS= read -r response; do printf '%s\\n' \"$response\"; [[ \"$response\" == *\"\\\"id\\\":2\"* ]] && break; done <&\"${CODEX_APP[0]}\""

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

  function refresh() {
    if (usageProcess.running) return
    _usageOutput = ""
    _usageError = ""
    refreshing = true
    statusText = qsTr("Loading Codex usage...")
    usageProcess.command = ["bash", "-c", appServerScript]
    usageProcess.running = true
  }

  function applyUsage(usage) {
    planType = usage.planType
    limitReached = usage.limitReached
    primaryWindow = usage.primaryWindow
    secondaryWindow = usage.secondaryWindow
    lastError = ""
    statusText = qsTr("Codex usage updated")
  }

  function fail(detail) {
    var kind = Model.errorKind(detail)
    if (kind === "missing-cli") {
      statusText = qsTr("Codex CLI is not installed")
      lastError = qsTr("Install Codex CLI and make it available on PATH.")
    } else if (kind === "authentication") {
      statusText = qsTr("Codex sign-in required")
      lastError = qsTr("Run codex login to sign in.")
    } else {
      statusText = qsTr("Could not retrieve Codex usage")
      lastError = qsTr("Press refresh to try again.")
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: usageProcess

    running: false
    command: []
    stdout: StdioCollector {
      id: usageStdout
      waitForEnd: true
      onStreamFinished: root._usageOutput = text
    }
    stderr: StdioCollector {
      id: usageStderr
      waitForEnd: true
      onStreamFinished: root._usageError = text
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var output = String(usageStdout.text || root._usageOutput || "")
      var error = String(usageStderr.text || root._usageError || "")
      if (exitCode !== 0) {
        root.fail(error || output)
        return
      }

      try {
        root.applyUsage(Model.parseAppServerOutput(output))
      } catch (exception) {
        root.fail(exception && exception.message ? exception.message : output)
      }
    }
  }
}
