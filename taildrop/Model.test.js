const assert = require("node:assert/strict")
const Model = require("./Model.js")

const targets = Model.parseTargets([
  "100.99.0.3\tzeta.tailnet.ts.net.\toffline; last seen 2m ago",
  "fd7a:115c:a1e0::5\talpha.tailnet.ts.net.",
  "100.99.0.2\talpha.tailnet.ts.net.",
  "not-an-address\tignored.tailnet.ts.net.",
  "100.99.0.2\tduplicate.tailnet.ts.net."
].join("\n"))

assert.deepEqual(
  targets.map(target => [target.address, target.displayName, target.offline]),
  [
    ["100.99.0.2", "alpha", false],
    ["fd7a:115c:a1e0::5", "alpha", false],
    ["100.99.0.3", "zeta", true]
  ]
)
assert.equal(Model.targetArgument(targets[0]), "100.99.0.2:")
assert.equal(Model.targetArgument(targets[1]), "[fd7a:115c:a1e0::5]:")
assert.equal(Model.targetArgument(null), "")
assert.equal(Model.fileSummary([]), "No files selected")
assert.equal(Model.fileSummary(["/home/user/report final.pdf"]), "report final.pdf")
assert.equal(Model.fileSummary(["/tmp/a", "/tmp/b"]), "2 files selected")
assert.equal(Model.elideStatus("one\n two\t three", 100), "one two three")
assert.equal(Model.elideStatus("abcdef", 5), "ab...")
assert.equal(Model.receivedFileCount("moved 2/2 files"), 2)
assert.equal(Model.receivedFileCount("moved 0/0 files"), 0)
