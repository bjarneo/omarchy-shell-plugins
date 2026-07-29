function numberOrNull(value) {
  var number = Number(value)
  return isFinite(number) ? number : null
}

function percent(value) {
  var number = numberOrNull(value)
  if (number === null) return null
  return Math.max(0, Math.min(100, number))
}

function parseWindow(value) {
  if (!value || typeof value !== "object") return null

  var usedPercent = percent(value.usedPercent)
  if (usedPercent === null) return null

  var windowDurationMins = numberOrNull(value.windowDurationMins)
  var resetsAt = numberOrNull(value.resetsAt)
  return {
    usedPercent: usedPercent,
    windowDurationMins: windowDurationMins !== null && windowDurationMins >= 0 ? windowDurationMins : null,
    resetsAt: resetsAt !== null && resetsAt >= 0 ? resetsAt : null
  }
}

function rateLimitsFor(result) {
  if (!result || typeof result !== "object") return null
  if (result.rateLimits) return result.rateLimits

  var byId = result.rateLimitsByLimitId
  if (!byId || typeof byId !== "object") return null
  if (byId.codex) return byId.codex

  var ids = Object.keys(byId)
  return ids.length > 0 ? byId[ids[0]] : null
}

function parseRateLimits(result) {
  var rateLimits = rateLimitsFor(result)
  if (!rateLimits || typeof rateLimits !== "object") throw new Error("Codex returned no usage limits")

  var primaryWindow = parseWindow(rateLimits.primary)
  if (!primaryWindow) throw new Error("Codex returned no primary usage limit")

  return {
    planType: String(rateLimits.planType || ""),
    limitReached: rateLimits.rateLimitReachedType !== null && rateLimits.rateLimitReachedType !== undefined,
    primaryWindow: primaryWindow,
    secondaryWindow: parseWindow(rateLimits.secondary)
  }
}

function parseAppServerOutput(output) {
  var lines = String(output || "").split(/\r?\n/)
  var response = null

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() === "") continue

    var message
    try {
      message = JSON.parse(lines[i])
    } catch (_) {
      continue
    }

    if (message.id === 2) {
      response = message
      break
    }
  }

  if (!response) throw new Error("Codex returned no usage response")
  if (response.error) throw new Error(String(response.error.message || "Codex could not retrieve usage"))
  return parseRateLimits(response.result)
}

function remainingPercent(rateWindow) {
  return rateWindow ? Math.max(0, Math.min(100, 100 - rateWindow.usedPercent)) : null
}

function remainingText(rateWindow) {
  var value = remainingPercent(rateWindow)
  return value === null ? "--" : String(Math.round(value)) + "%"
}

function resetAfterSeconds(rateWindow, nowMs) {
  if (!rateWindow || rateWindow.resetsAt === null) return null
  return Math.max(0, Math.round(rateWindow.resetsAt - (Number(nowMs) || Date.now()) / 1000))
}

function durationText(seconds) {
  var value = Math.max(0, Math.round(Number(seconds) || 0))
  var days = Math.floor(value / 86400)
  var hours = Math.floor(value % 86400 / 3600)
  var minutes = Math.floor(value % 3600 / 60)

  if (days > 0) return String(days) + "d " + String(hours) + "h"
  if (hours > 0) return String(hours) + "h " + String(minutes) + "m"
  return String(minutes) + "m"
}

function errorKind(detail) {
  var text = String(detail || "")
  if (/command not found|codex cli is not installed/i.test(text)) return "missing-cli"
  if (/authentication required|not logged in|sign in/i.test(text)) return "authentication"
  return "unavailable"
}

if (typeof module !== "undefined") {
  module.exports = {
    parseWindow: parseWindow,
    parseRateLimits: parseRateLimits,
    parseAppServerOutput: parseAppServerOutput,
    remainingPercent: remainingPercent,
    remainingText: remainingText,
    resetAfterSeconds: resetAfterSeconds,
    durationText: durationText,
    errorKind: errorKind
  }
}
