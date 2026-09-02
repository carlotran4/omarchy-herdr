import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../Herdr.js", import.meta.url), "utf8")
  .replace(/^\.pragma library\s*/, "")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(source, sandbox, { filename: "Herdr.js" })
const Herdr = sandbox.module.exports

const agents = [
  { pane_id: "idle", name: "idle-agent", agent_status: "idle", state_change_seq: 99 },
  { pane_id: "done-old", name: "done-old", agent_status: "done", state_change_seq: 4 },
  { pane_id: "blocked", name: "blocked-agent", agent_status: "blocked", state_change_seq: 1 },
  { pane_id: "done-new", name: "done-new", agent_status: "done", state_change_seq: 8 },
  { pane_id: "future", name: "future-agent", agent_status: "new-state", state_change_seq: 200 }
]

assert.equal(Herdr.normalizeStatus(agents[4]), "unknown")
assert.deepEqual({ ...Herdr.counts(agents) }, {
  blocked: 1,
  done: 2,
  working: 0,
  unknown: 1,
  idle: 1
})
assert.equal(Herdr.attentionAgent(agents).pane_id, "blocked")
assert.equal(Herdr.attentionAgent(agents.slice(1, 2).concat(agents.slice(3, 4))).pane_id, "done-new")
assert.deepEqual(Array.from(Herdr.sortedAgents(agents), agent => agent.pane_id), [
  "blocked", "done-new", "done-old", "future", "idle"
])

assert.equal(Herdr.targetFor({ name: "named", pane_id: "pane" }), "named")
assert.equal(Herdr.targetFor({ pane_id: "pane" }), "pane")
assert.equal(Herdr.shortenPath("/home/carlo/Developer/project", "/home/carlo"), "~/Developer/project")
assert.equal(Herdr.socketPath("/home/carlo", "default", ""), "/home/carlo/.config/herdr/herdr.sock")
assert.equal(Herdr.socketPath("/home/carlo", "work", ""), "/home/carlo/.config/herdr/sessions/work/herdr.sock")
assert.equal(Herdr.socketPath("/home/carlo", "work", "~/custom.sock"), "/home/carlo/custom.sock")
assert.equal(Herdr.subscriptions(agents).filter(item => item.type === "pane.agent_status_changed").length, 5)
assert.equal(Herdr.paneKey([{ pane_id: "b" }, { pane_id: "a" }]), "a\nb")
assert.match(Herdr.tooltip([agents[2]], true, "/home/carlo"), /Blocked  blocked-agent/)
assert.match(Herdr.tooltip([], false, "/home/carlo"), /offline/)

console.log("Herdr model tests passed")
