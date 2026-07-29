const assert = require("node:assert/strict")
const Model = require("./Model.js")

const usage = Model.parseAppServerOutput([
  "{\"method\":\"account/rateLimits/updated\",\"params\":{}}",
  "{\"id\":2,\"result\":{\"rateLimits\":{\"limitId\":\"codex\",\"limitName\":null,\"primary\":{\"usedPercent\":25,\"windowDurationMins\":10080,\"resetsAt\":1785935803},\"secondary\":{\"usedPercent\":10,\"windowDurationMins\":300,\"resetsAt\":1785335803},\"planType\":\"prolite\",\"rateLimitReachedType\":null}}}"
].join("\n"))

assert.deepEqual(usage, {
  planType: "prolite",
  limitReached: false,
  primaryWindow: {
    usedPercent: 25,
    windowDurationMins: 10080,
    resetsAt: 1785935803
  },
  secondaryWindow: {
    usedPercent: 10,
    windowDurationMins: 300,
    resetsAt: 1785335803
  }
})

assert.deepEqual(Model.parseRateLimits({
  rateLimitsByLimitId: {
    codex: {
      primary: { usedPercent: 110 },
      secondary: null,
      planType: "plus",
      rateLimitReachedType: "rate_limit_reached"
    }
  }
}), {
  planType: "plus",
  limitReached: true,
  primaryWindow: {
    usedPercent: 100,
    windowDurationMins: null,
    resetsAt: null
  },
  secondaryWindow: null
})

assert.equal(Model.remainingPercent(usage.primaryWindow), 75)
assert.equal(Model.remainingText(usage.primaryWindow), "75%")
assert.equal(Model.remainingText(null), "--")
assert.equal(Model.resetAfterSeconds({ resetsAt: 120 }, 100000), 20)
assert.equal(Model.resetAfterSeconds(null, 0), null)
assert.equal(Model.durationText(93720), "1d 2h")
assert.equal(Model.durationText(7260), "2h 1m")
assert.equal(Model.durationText(120), "2m")
assert.equal(Model.errorKind("codex: command not found"), "missing-cli")
assert.equal(Model.errorKind("Codex account authentication required"), "authentication")
