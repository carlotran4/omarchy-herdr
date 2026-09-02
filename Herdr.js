.pragma library

var STATUS_ORDER = ["blocked", "done", "working", "unknown", "idle"]
var STATUS_LABELS = {
  blocked: "Blocked",
  done: "Done",
  working: "Working",
  unknown: "Unknown",
  idle: "Idle"
}
var STATUS_ICONS = {
  blocked: "󰀦",
  done: "󰄬",
  working: "󰔟",
  unknown: "󰘥",
  idle: "󰒲"
}

function normalizeStatus(agent) {
  var value = String(agent && agent.agent_status || "unknown")
  return STATUS_ORDER.indexOf(value) >= 0 ? value : "unknown"
}

function priority(status) {
  var index = STATUS_ORDER.indexOf(status)
  return index < 0 ? STATUS_ORDER.indexOf("unknown") : index
}

function counts(agents) {
  var result = { blocked: 0, done: 0, working: 0, unknown: 0, idle: 0 }
  var rows = agents || []
  for (var i = 0; i < rows.length; i++) result[normalizeStatus(rows[i])]++
  return result
}

function sortedAgents(agents) {
  return (agents || []).slice().sort(function(a, b) {
    var statusDelta = priority(normalizeStatus(a)) - priority(normalizeStatus(b))
    if (statusDelta !== 0) return statusDelta
    return agentLabel(a).toLowerCase().localeCompare(agentLabel(b).toLowerCase())
  })
}

function attentionAgent(agents) {
  var rows = agents || []
  if (rows.length === 0) return null
  return rows.slice().sort(function(a, b) {
    var statusDelta = priority(normalizeStatus(a)) - priority(normalizeStatus(b))
    if (statusDelta !== 0) return statusDelta
    return Number(b.state_change_seq || 0) - Number(a.state_change_seq || 0)
  })[0]
}

function targetFor(agent) {
  if (!agent) return ""
  return String(agent.name || agent.pane_id || "")
}

function agentLabel(agent, maxLength) {
  var text = String(agent && (agent.name || agent.display_agent || agent.agent || agent.pane_id) || "agent")
  var limit = maxLength || 32
  return text.length <= limit ? text : text.slice(0, limit - 1) + "…"
}

function shortenPath(rawPath, home, maxLength) {
  if (!rawPath) return ""
  var path = String(rawPath)
  if (home && path.indexOf(home) === 0) path = "~" + path.slice(home.length)
  var limit = maxLength || 48
  if (path.length <= limit) return path
  var parts = path.split("/")
  return "…/" + parts.slice(-2).join("/")
}

function paneKey(agents) {
  return (agents || []).map(function(agent) { return String(agent.pane_id || "") })
    .filter(function(id) { return id !== "" }).sort().join("\n")
}

function socketPath(home, session, explicitPath) {
  var explicit = String(explicitPath || "").trim()
  if (explicit !== "") return explicit.replace(/^~(?=\/)/, home)
  var name = String(session || "default").trim()
  if (name === "" || name === "default") return home + "/.config/herdr/herdr.sock"
  return home + "/.config/herdr/sessions/" + name + "/herdr.sock"
}

function subscriptions(agents) {
  var list = [
    { type: "pane.agent_detected" },
    { type: "pane.closed" },
    { type: "pane.exited" },
    { type: "pane.moved" }
  ]
  var rows = agents || []
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].pane_id) list.push({ type: "pane.agent_status_changed", pane_id: rows[i].pane_id })
  }
  return list
}

function tooltip(agents, online, home) {
  if (!online) return "Herdr is offline · waiting to reconnect"
  var rows = sortedAgents(agents)
  if (rows.length === 0) return "Herdr · no active agents"
  var lines = ["Herdr · " + rows.length + " agent" + (rows.length === 1 ? "" : "s"), ""]
  for (var i = 0; i < rows.length; i++) {
    var status = normalizeStatus(rows[i])
    var cwd = shortenPath(rows[i].foreground_cwd || rows[i].cwd, home)
    lines.push(STATUS_ICONS[status] + "  " + STATUS_LABELS[status] + "  " + agentLabel(rows[i]))
    if (cwd !== "") lines.push("    " + cwd)
  }
  lines.push("", "Left-click: focus what needs you · Right-click: open dashboard")
  return lines.join("\n")
}

if (typeof module !== "undefined") {
  module.exports = {
    STATUS_ORDER: STATUS_ORDER,
    STATUS_LABELS: STATUS_LABELS,
    normalizeStatus: normalizeStatus,
    counts: counts,
    sortedAgents: sortedAgents,
    attentionAgent: attentionAgent,
    targetFor: targetFor,
    agentLabel: agentLabel,
    shortenPath: shortenPath,
    paneKey: paneKey,
    socketPath: socketPath,
    subscriptions: subscriptions,
    tooltip: tooltip
  }
}
