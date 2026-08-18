import QtQuick
import qs.Commons

Item {
  id: root

  property var bands: []
  property string mode: "ClassicLED"
  property color lowColor: Color.accent
  property color midColor: Color.foreground
  property color highColor: Color.urgent
  property color peakColor: Color.foreground
  property int segmentHeight: 3
  property int segmentGap: 2
  property bool showPeaks: true
  property var peaks: []
  property int frame: 0

  readonly property string modeKey: String(mode || "Bars").toLowerCase()

  function request() { canvas.requestPaint() }

  function _clamp(value) {
    return Math.max(0, Math.min(1, Number(value) || 0))
  }

  function _sample(values, position) {
    if (!values || values.length === 0) return 0
    if (values.length === 1) return _clamp(values[0])
    var bounded = Math.max(0, Math.min(values.length - 1, position))
    var left = Math.floor(bounded)
    var right = Math.min(values.length - 1, left + 1)
    var fraction = bounded - left
    return _clamp(values[left]) * (1 - fraction) + _clamp(values[right]) * fraction
  }

  function _energy(values) {
    if (!values || values.length === 0) return 0
    var total = 0
    for (var i = 0; i < values.length; i++) total += _clamp(values[i])
    return total / values.length
  }

  function _colorFor(level) {
    return level < 0.55 ? lowColor : (level < 0.82 ? midColor : highColor)
  }

  function _hash(a, b, c) {
    var value = Math.sin(a * 12.9898 + b * 78.233 + c * 0.137) * 43758.5453
    return value - Math.floor(value)
  }

  function _usesPeaks() {
    return modeKey === "classicpeak" || modeKey === "classicled" || modeKey === "columns"
  }

  function _isAnimated() {
    switch (modeKey) {
    case "rain":
    case "scatter":
    case "flame":
    case "matrix":
    case "binary":
    case "sakura":
    case "firefly":
    case "mosaic":
    case "sand":
    case "geyser":
      return true
    default:
      return false
    }
  }

  onBandsChanged: {
    if ((!bands || bands.length === 0) && peaks.length > 0) peaks = []
    request()
  }
  onModeChanged: {
    peaks = []
    frame = 0
    request()
  }
  onLowColorChanged: request()
  onMidColorChanged: request()
  onHighColorChanged: request()
  onPeakColorChanged: request()

  Behavior on lowColor { ColorAnimation { duration: 160 } }
  Behavior on midColor { ColorAnimation { duration: 160 } }
  Behavior on highColor { ColorAnimation { duration: 160 } }
  Behavior on peakColor { ColorAnimation { duration: 160 } }

  Timer {
    interval: 40
    running: root.visible && root.bands && root.bands.length > 0
      && (root._usesPeaks() || root._isAnimated())
    repeat: true
    onTriggered: {
      root.frame = (root.frame + 1) % 100000
      var dirty = root._isAnimated()
      if (root._usesPeaks()) {
        var count = root.bands.length
        var current = root.peaks || []
        var next = []
        dirty = dirty || current.length !== count
        for (var i = 0; i < count; i++) {
          var band = root._clamp(root.bands[i])
          var peak = Number(current[i] || 0)
          var value = band >= peak ? band : Math.max(0, peak - 0.022)
          next.push(value)
          if (Math.abs(value - peak) > 0.001) dirty = true
        }
        if (dirty) root.peaks = next
      }
      if (dirty) canvas.requestPaint()
    }
  }

  function _drawBarFamily(ctx, width, height, values, kind) {
    var sourceCount = values.length
    var count = kind === "columns"
      ? Math.max(sourceCount, Math.min(64, Math.floor(width / 6)))
      : sourceCount
    var gap = kind === "bricks" ? 4 : (count > 8 ? 2 : 3)
    var barWidth = Math.max(1, (width - gap * (count - 1)) / count)
    var segmented = kind === "bricks" || kind === "classicled" || kind === "ascii"
    var dotted = kind === "barsdot"
    var outlined = kind === "barsoutline"
    var step = segmentHeight + segmentGap
    var rows = Math.max(2, Math.floor(height / step))

    for (var index = 0; index < count; index++) {
      var sourcePosition = count === 1 ? 0 : index * (sourceCount - 1) / (count - 1)
      var value = _sample(values, sourcePosition)
      var x = index * (barWidth + gap)
      var barHeight = Math.max(1, value * height)
      var y = height - barHeight

      if (outlined) {
        ctx.strokeStyle = _colorFor(value)
        ctx.lineWidth = Math.max(1, Math.min(2, barWidth / 3))
        ctx.strokeRect(x, y, barWidth, barHeight)
      } else if (dotted) {
        var dot = Math.max(1, Math.min(3, barWidth / 2))
        var litRows = Math.round(value * rows)
        for (var dotRow = 0; dotRow < litRows; dotRow++) {
          var dotY = height - (dotRow + 1) * step + segmentGap
          ctx.fillStyle = _colorFor(dotRow / rows)
          ctx.fillRect(x, dotY, dot, dot)
          if (barWidth > dot * 2) ctx.fillRect(x + barWidth - dot, dotY, dot, dot)
        }
      } else if (segmented) {
        var segments = Math.round(value * rows)
        for (var row = 0; row < segments; row++) {
          var rowY = height - (row + 1) * step + segmentGap
          if (rowY < 0) break
          ctx.fillStyle = _colorFor(row / rows)
          if (kind === "ascii") ctx.globalAlpha = 0.45 + 0.55 * ((row + index) % 3) / 2
          ctx.fillRect(x, rowY, barWidth, segmentHeight)
        }
        ctx.globalAlpha = 1
      } else {
        ctx.fillStyle = _colorFor(value)
        ctx.fillRect(x, y, barWidth, barHeight)
      }

      if (showPeaks && _usesPeaks()) {
        var peakIndex = Math.min(sourceCount - 1, Math.round(sourcePosition))
        var peak = _clamp(peaks[peakIndex] || 0)
        if (peak > 0.02) {
          ctx.fillStyle = peakColor
          ctx.fillRect(x, Math.max(0, height - peak * height), barWidth, Math.max(1, segmentHeight - 1))
        }
      }
    }
  }

  function _drawWave(ctx, width, height, values, kind) {
    var points = Math.max(24, Math.floor(width / 5))
    ctx.beginPath()
    ctx.strokeStyle = kind === "heartbeat" ? highColor : midColor
    ctx.lineWidth = 2
    for (var i = 0; i < points; i++) {
      var x = i * width / Math.max(1, points - 1)
      var value = _sample(values, i * (values.length - 1) / Math.max(1, points - 1))
      var y
      if (kind === "scope") {
        y = height / 2 + (value - 0.5) * height * 0.8 * (i % 2 === 0 ? 1 : -1)
      } else if (kind === "heartbeat") {
        var phase = i % 12
        var spike = phase === 5 ? -value * height * 0.48 : (phase === 6 ? value * height * 0.28 : 0)
        y = height * 0.58 + spike
      } else {
        y = height * (0.86 - value * 0.72)
      }
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
  }

  function _drawStereo(ctx, width, height, values) {
    var left = 0
    var right = 0
    var leftCount = 0
    var rightCount = 0
    for (var i = 0; i < values.length; i++) {
      if (i % 2 === 0) { left += _clamp(values[i]); leftCount++ }
      else { right += _clamp(values[i]); rightCount++ }
    }
    left /= Math.max(1, leftCount)
    right /= Math.max(1, rightCount)
    var levels = [left, right]
    var segments = Math.max(12, Math.floor(width / 12))
    var gap = 2
    var segmentWidth = Math.max(1, (width - gap * (segments - 1)) / segments)
    for (var channel = 0; channel < 2; channel++) {
      var y = channel === 0 ? height * 0.22 : height * 0.66
      var lit = Math.round(levels[channel] * segments)
      for (var segment = 0; segment < lit; segment++) {
        ctx.fillStyle = _colorFor(segment / segments)
        ctx.fillRect(segment * (segmentWidth + gap), y, segmentWidth, height * 0.16)
      }
    }
  }

  function _drawButterfly(ctx, width, height, values) {
    var count = values.length
    var gap = count > 8 ? 2 : 3
    var barWidth = Math.max(1, (width - gap * (count - 1)) / count)
    var center = height / 2
    for (var i = 0; i < count; i++) {
      var value = _clamp(values[i])
      var span = value * center * 0.92
      ctx.fillStyle = _colorFor(value)
      ctx.fillRect(i * (barWidth + gap), center - span, barWidth, span * 2)
    }
  }

  function _drawTerrain(ctx, width, height, values, retro) {
    if (retro) {
      ctx.strokeStyle = lowColor
      ctx.lineWidth = 1
      for (var grid = 1; grid < 5; grid++) {
        var gridY = height * (0.55 + grid * grid * 0.018)
        ctx.beginPath(); ctx.moveTo(0, gridY); ctx.lineTo(width, gridY); ctx.stroke()
      }
    }
    var points = Math.max(24, Math.floor(width / 8))
    ctx.beginPath()
    ctx.moveTo(0, height)
    for (var i = 0; i < points; i++) {
      var x = i * width / Math.max(1, points - 1)
      var value = _sample(values, i * (values.length - 1) / Math.max(1, points - 1))
      var y = height * (0.92 - value * (retro ? 0.58 : 0.82))
      ctx.lineTo(x, y)
    }
    ctx.lineTo(width, height)
    ctx.closePath()
    ctx.globalAlpha = retro ? 0.25 : 0.5
    ctx.fillStyle = lowColor
    ctx.fill()
    ctx.globalAlpha = 1
    ctx.strokeStyle = retro ? highColor : midColor
    ctx.lineWidth = 2
    ctx.stroke()
  }

  function _drawRadial(ctx, width, height, values, kind) {
    var energy = _energy(values)
    var centerX = width / 2
    var centerY = height / 2
    var maxRadius = Math.min(width, height) * 0.42
    ctx.strokeStyle = kind === "firework" ? highColor : midColor
    ctx.fillStyle = lowColor
    if (kind === "pulse") {
      ctx.beginPath()
      ctx.lineWidth = 2
      ctx.arc(centerX, centerY, Math.max(3, maxRadius * (0.28 + energy * 0.62)), 0, Math.PI * 2)
      ctx.stroke()
      return
    }
    for (var i = 0; i < values.length; i++) {
      var angle = i / values.length * Math.PI * 2
      var value = _clamp(values[i])
      var radius = maxRadius * (0.2 + value * 0.75)
      var x = centerX + Math.cos(angle) * radius
      var y = centerY + Math.sin(angle) * radius
      if (kind === "firework") {
        ctx.beginPath(); ctx.moveTo(centerX, centerY); ctx.lineTo(x, y); ctx.stroke()
      } else {
        ctx.beginPath(); ctx.arc(x, y, 2 + value * 5, 0, Math.PI * 2); ctx.stroke()
      }
    }
  }

  function _drawParticles(ctx, width, height, values, kind) {
    var count = Math.min(96, Math.max(36, values.length * 5))
    for (var i = 0; i < count; i++) {
      var bandIndex = i % values.length
      var level = _clamp(values[bandIndex])
      var seed = _hash(i, bandIndex, 0)
      var phase = (seed + frame * (0.006 + (i % 5) * 0.001)) % 1
      var x = (bandIndex + _hash(i, frame, 2)) / values.length * width
      var y
      if (kind === "flame" || kind === "geyser" || kind === "firefly") {
        y = height - phase * height * Math.max(0.18, level)
      } else if (kind === "sand") {
        y = height - level * height + phase * level * height
      } else {
        y = phase * height
        if (y < height * (1 - level)) continue
      }
      var size = kind === "matrix" || kind === "rain" ? 1 + level * 2 : 1 + level * 3
      ctx.fillStyle = _colorFor(level)
      ctx.globalAlpha = kind === "firefly" ? 0.35 + 0.65 * _hash(i, frame, 4) : 0.8
      if (kind === "sakura") {
        ctx.save(); ctx.translate(x, y); ctx.rotate(seed * Math.PI); ctx.fillRect(-size, -1, size * 2, 2); ctx.restore()
      } else if (kind === "binary") {
        ctx.fillRect(x, y, size, size * 2)
      } else {
        ctx.fillRect(x, y, size, size)
      }
    }
    ctx.globalAlpha = 1
  }

  function _drawMosaic(ctx, width, height, values) {
    var columns = Math.max(8, Math.min(20, values.length))
    var rows = 5
    var gap = 2
    var tileWidth = (width - gap * (columns - 1)) / columns
    var tileHeight = (height - gap * (rows - 1)) / rows
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        var value = _sample(values, column * (values.length - 1) / Math.max(1, columns - 1))
        var flicker = 0.55 + _hash(row, column, Math.floor(frame / 3)) * 0.45
        ctx.fillStyle = _colorFor(value)
        ctx.globalAlpha = Math.max(0.12, value * flicker)
        ctx.fillRect(column * (tileWidth + gap), row * (tileHeight + gap), tileWidth, tileHeight)
      }
    }
    ctx.globalAlpha = 1
  }

  function _drawLogo(ctx, width, height, values) {
    var energy = _energy(values)
    ctx.fillStyle = _colorFor(Math.max(0.25, energy))
    ctx.globalAlpha = 0.55 + energy * 0.45
    ctx.font = "bold " + Math.max(14, Math.min(42, height * 0.45)) + "px monospace"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText("CLIAMP", width / 2, height / 2)
    ctx.globalAlpha = 1
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    onPaint: {
      var ctx = getContext("2d")
      var width = canvas.width
      var height = canvas.height
      ctx.clearRect(0, 0, width, height)

      var values = root.bands || []
      if (values.length === 0 || width <= 0 || height <= 0 || root.modeKey === "none") return

      switch (root.modeKey) {
      case "wave":
      case "scope":
      case "heartbeat":
        root._drawWave(ctx, width, height, values, root.modeKey)
        break
      case "stereo":
        root._drawStereo(ctx, width, height, values)
        break
      case "butterfly":
        root._drawButterfly(ctx, width, height, values)
        break
      case "terrain":
        root._drawTerrain(ctx, width, height, values, false)
        break
      case "retro":
        root._drawTerrain(ctx, width, height, values, true)
        break
      case "pulse":
      case "bubbles":
      case "firework":
        root._drawRadial(ctx, width, height, values, root.modeKey)
        break
      case "rain":
      case "scatter":
      case "flame":
      case "matrix":
      case "binary":
      case "sakura":
      case "firefly":
      case "sand":
      case "geyser":
        root._drawParticles(ctx, width, height, values, root.modeKey)
        break
      case "mosaic":
        root._drawMosaic(ctx, width, height, values)
        break
      case "logo":
        root._drawLogo(ctx, width, height, values)
        break
      default:
        root._drawBarFamily(ctx, width, height, values, root.modeKey)
        break
      }
    }
  }
}
