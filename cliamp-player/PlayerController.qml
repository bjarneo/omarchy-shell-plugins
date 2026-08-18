import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  required property bool captureEnabled
  required property bool spectrumEnabled

  property bool running: false
  property bool playing: false
  property bool paused: false
  property string title: ""
  property string artist: ""
  property string album: ""
  property real positionSeconds: 0
  property real durationSeconds: 0
  property int volume: 0
  property bool shuffle: false
  property string repeatMode: "Off"
  property string trackKey: ""
  property var bands: []
  property bool analyzerFailed: false
  property bool analyzerStopping: false
  property int pendingVolume: 0
  property string pendingRepeatMode: "off"
  property string visualizerMode: "Bars"
  property bool visualizerChangePending: false
  property var visualizerOptions: [{ value: "Bars", label: "Bars" }]

  readonly property real progress: durationSeconds > 0
    ? Math.max(0, Math.min(1, positionSeconds / durationSeconds))
    : 0
  readonly property string playIcon: playing ? "⏸" : "▶"
  readonly property string analyzerPath: {
    var path = Qt.resolvedUrl("analyzer.py").toString()
    if (path.indexOf("file://") === 0) path = path.substring(7)
    try { return decodeURIComponent(path) } catch (error) { return path }
  }

  signal trackChanged()

  function formatTime(seconds) {
    var value = Math.max(0, Math.floor(Number(seconds) || 0))
    var minutes = Math.floor(value / 60)
    var remainder = value % 60
    return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
  }

  function displayTitle() {
    return title || (running ? "Unknown track" : "cliamp")
  }

  function displayArtist() {
    var parts = []
    if (artist) parts.push(artist)
    if (album) parts.push(album)
    return parts.join(" · ")
  }

  function _prettyVisualizerName(name) {
    return String(name || "")
      .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
      .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
  }

  function _parseVisualizers(raw) {
    var options = []
    var seen = ({})
    var lines = String(raw || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var name = lines[i].trim()
      if (name.charAt(0) === "*") name = name.substring(1).trim()
      var normalized = name.toLowerCase()
      if (name === "" || seen[normalized]) continue
      seen[normalized] = true
      options.push({ value: name, label: _prettyVisualizerName(name) })
    }
    if (options.length > 0) visualizerOptions = options
  }

  function loadVisualizers() {
    if (!visualizerListProc.running) visualizerListProc.running = true
  }

  function setVisualizer(value) {
    var mode = String(value || "")
    var options = visualizerOptions || []
    var found = false
    for (var i = 0; i < options.length; i++) {
      if (String(options[i].value) === mode) {
        found = true
        break
      }
    }
    if (!found || mode === visualizerMode) return
    visualizerMode = mode
    visualizerChangePending = true
    _runCommand(["vis", mode])
  }

  function poll() {
    if (!captureEnabled || statusProc.running) return
    statusProc.running = true
    statusWatchdog.restart()
  }

  function _runCommand(args) {
    Quickshell.execDetached(["cliamp"].concat(args))
    commandRefresh.restart()
  }

  function togglePlayback() { _runCommand(["toggle"]) }
  function nextTrack() { _runCommand(["next"]) }
  function previousTrack() { _runCommand(["prev"]) }
  function stopPlayback() { _runCommand(["stop"]) }
  function toggleShuffle() {
    shuffle = !shuffle
    _runCommand(["shuffle"])
  }

  function seekFraction(value) {
    if (durationSeconds <= 0) return
    var fraction = Math.max(0, Math.min(1, Number(value) || 0))
    var offset = Math.round(durationSeconds * fraction - positionSeconds)
    if (offset === 0) return
    _runCommand(["seek", offset > 0 ? "+" + offset : String(offset)])
  }

  function changeVolume(direction) {
    var delta = Number(direction) || 0
    if (delta === 0) return
    var target = Math.max(-30, Math.min(6, volume + (delta > 0 ? 2 : -2)))
    volume = target
    pendingVolume = target
    volumeCommit.restart()
  }

  function cycleRepeat() {
    var current = repeatMode.toLowerCase()
    var next = current === "off" ? "all" : (current === "all" ? "one" : "off")
    repeatMode = next.charAt(0).toUpperCase() + next.substring(1)
    pendingRepeatMode = next
    repeatCommit.restart()
  }

  function _setUnavailable() {
    statusWatchdog.stop()
    volumeCommit.stop()
    repeatCommit.stop()
    running = false
    playing = false
    paused = false
    title = ""
    artist = ""
    album = ""
    positionSeconds = 0
    durationSeconds = 0
    volume = 0
    pendingVolume = 0
    shuffle = false
    repeatMode = "Off"
    pendingRepeatMode = "off"
    visualizerMode = "Bars"
    visualizerChangePending = false
    trackKey = ""
    _syncAnalyzer()
  }

  function _parseStatus(raw) {
    if (!raw || String(raw).trim() === "") {
      _setUnavailable()
      return
    }

    try {
      var data = JSON.parse(String(raw).trim())
      if (!data || data.ok !== true) {
        _setUnavailable()
        return
      }

      var state = String(data.state || "").toLowerCase()
      var track = data.track || ({})
      var nextTitle = String(track.title || "")
      var nextArtist = String(track.artist || "")
      var nextAlbum = String(track.album || "")
      var identityParts = [String(track.path || ""), nextTitle, nextArtist, String(track.index || "")]
      var nextKey = identityParts.join("|")
      var hasIdentity = identityParts.join("") !== ""
      var changed = hasIdentity && nextKey !== trackKey

      running = true
      playing = state === "playing"
      paused = state === "paused"
      title = nextTitle
      artist = nextArtist
      album = nextAlbum
      positionSeconds = Number(data.position || 0)
      durationSeconds = Number(data.duration || track.duration_secs || 0)
      var reportedVolume = Math.round(Number(data.volume || 0))
      if (!volumeCommit.running && !commandRefresh.running) {
        volume = reportedVolume
        pendingVolume = reportedVolume
      }
      shuffle = Boolean(data.shuffle)
      var reportedRepeat = String(data.repeat || "Off")
      if (!repeatCommit.running && !commandRefresh.running) {
        repeatMode = reportedRepeat
        pendingRepeatMode = reportedRepeat.toLowerCase()
      }
      if (!visualizerChangePending || !commandRefresh.running) {
        visualizerMode = String(data.visualizer || "Bars")
        visualizerChangePending = false
      }
      trackKey = hasIdentity ? nextKey : ""

      _syncAnalyzer()
      if (changed) trackChanged()
    } catch (error) {
      console.warn("cliamp-player status:", error)
      _setUnavailable()
    }
  }

  function _parseFrame(line) {
    if (!_wantsAnalyzer()) return
    try {
      var frame = JSON.parse(String(line).trim())
      if (!frame || !Array.isArray(frame.bands) || frame.bands.length === 0) return
      bands = frame.bands
    } catch (error) {
      console.warn("cliamp-player spectrum:", error)
    }
  }

  function _wantsAnalyzer() {
    return captureEnabled && spectrumEnabled && playing
      && visualizerMode.toLowerCase() !== "none"
  }

  function _syncAnalyzer() {
    var shouldRun = _wantsAnalyzer() && !analyzerFailed
    if (shouldRun && !analyzerProc.running && !analyzerStopping) {
      analyzerProc.running = true
    } else if (!shouldRun && analyzerProc.running) {
      analyzerStopping = true
      analyzerProc.running = false
    }
    if (!shouldRun) bands = []
  }

  onCaptureEnabledChanged: {
    analyzerFailed = false
    if (!captureEnabled) {
      statusWatchdog.stop()
      if (statusProc.running) statusProc.running = false
    } else {
      poll()
    }
    _syncAnalyzer()
  }

  onSpectrumEnabledChanged: {
    analyzerFailed = false
    _syncAnalyzer()
  }

  onPlayingChanged: {
    analyzerFailed = false
    _syncAnalyzer()
  }

  onVisualizerModeChanged: {
    analyzerFailed = false
    _syncAnalyzer()
  }

  Component.onCompleted: {
    poll()
    _syncAnalyzer()
  }

  Component.onDestruction: {
    statusProc.running = false
    analyzerProc.running = false
    visualizerListProc.running = false
  }

  Timer {
    id: statusTimer
    interval: root.playing ? 1000 : 2500
    running: root.captureEnabled
    repeat: true
    onTriggered: root.poll()
  }

  Timer {
    id: statusWatchdog
    interval: 2000
    repeat: false
    onTriggered: {
      if (!statusProc.running) return
      console.warn("cliamp-player status: command timed out")
      statusProc.running = false
      root._setUnavailable()
    }
  }

  Timer {
    id: volumeCommit
    interval: 50
    repeat: false
    onTriggered: root._runCommand(["volume", String(root.pendingVolume)])
  }

  Timer {
    id: repeatCommit
    interval: 50
    repeat: false
    onTriggered: root._runCommand(["repeat", root.pendingRepeatMode])
  }

  Timer {
    id: commandRefresh
    interval: 180
    repeat: false
    onTriggered: {
      if (statusProc.running) {
        commandRefresh.restart()
        return
      }
      root.poll()
    }
  }

  Process {
    id: statusProc
    command: ["cliamp", "status", "--json"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      statusWatchdog.stop()
      if (!root.captureEnabled) return
      if (exitCode === 0) root._parseStatus(stdout.text)
      else root._setUnavailable()
    }
  }

  Process {
    id: visualizerListProc
    command: ["cliamp", "vis", "list"]
    running: false
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root._parseVisualizers(stdout.text)
      } else {
        var detail = String(stderr.text || "").trim()
        if (detail !== "") console.warn("cliamp-player visualizers:", detail)
      }
    }
  }

  Process {
    id: analyzerProc
    command: ["python3", root.analyzerPath]
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root._parseFrame(line) }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var text = String(line || "").trim()
        if (text !== "") console.warn("cliamp-player analyzer:", text)
      }
    }
    onExited: function(_exitCode) {
      root.bands = []
      if (root.analyzerStopping) {
        root.analyzerStopping = false
        root._syncAnalyzer()
      } else if (root._wantsAnalyzer()) {
        root.analyzerFailed = true
      }
    }
  }
}
