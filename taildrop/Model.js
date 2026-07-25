function cleanTargetName(value) {
  var name = String(value || "").trim()
  return name.charAt(name.length - 1) === "." ? name.slice(0, -1) : name
}

function displayTargetName(value) {
  var name = cleanTargetName(value)
  if (name === "") return "Unknown device"
  return name.split(".")[0] || name
}

function isAddress(value) {
  var address = String(value || "").trim()
  if (/^(?:\d{1,3}\.){3}\d{1,3}$/.test(address)) return true
  return /^[0-9a-f:.]+$/i.test(address) && address.indexOf(":") !== -1
}

function parseTargets(raw) {
  var entries = []
  var seen = {}
  var lines = String(raw || "").split(/\r?\n/)

  for (var i = 0; i < lines.length; i++) {
    var fields = lines[i].split("\t")
    var address = String(fields[0] || "").trim()
    var name = cleanTargetName(fields[1])
    if (!isAddress(address) || name === "" || seen[address]) continue

    var detail = fields.slice(2).join("\t").trim()
    entries.push({
      address: address,
      name: name,
      displayName: displayTargetName(name),
      detail: detail,
      offline: /^offline(?:;|$)/i.test(detail)
    })
    seen[address] = true
  }

  entries.sort(function(a, b) {
    if (a.offline !== b.offline) return a.offline ? 1 : -1
    var nameCompare = a.displayName.localeCompare(b.displayName)
    return nameCompare !== 0 ? nameCompare : a.address.localeCompare(b.address)
  })
  return entries
}

function targetArgument(target) {
  var address = String(target && target.address || "").trim()
  if (address === "") return ""
  return address.indexOf(":") !== -1 ? "[" + address + "]:" : address + ":"
}

function elideStatus(value, maximumLength) {
  var text = String(value || "").replace(/\s+/g, " ").trim()
  var max = Number(maximumLength) || 160
  return text.length > max ? text.substring(0, Math.max(0, max - 3)) + "..." : text
}

function fileName(path) {
  var value = String(path || "")
  var slash = value.lastIndexOf("/")
  return slash === -1 ? value : value.substring(slash + 1)
}

function fileSummary(paths) {
  var count = Array.isArray(paths) ? paths.length : 0
  if (count === 0) return "No files selected"
  if (count === 1) return fileName(paths[0]) || "1 file selected"
  return String(count) + " files selected"
}

function receivedFileCount(output) {
  var match = String(output || "").match(/\bmoved\s+(\d+)\/\d+\s+files\b/i)
  return match ? parseInt(match[1], 10) || 0 : 0
}

if (typeof module !== "undefined") {
  module.exports = {
    cleanTargetName: cleanTargetName,
    displayTargetName: displayTargetName,
    isAddress: isAddress,
    parseTargets: parseTargets,
    targetArgument: targetArgument,
    elideStatus: elideStatus,
    fileName: fileName,
    fileSummary: fileSummary,
    receivedFileCount: receivedFileCount
  }
}
