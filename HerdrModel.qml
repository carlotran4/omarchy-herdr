import QtQuick
import Quickshell.Io
import "Herdr.js" as Herdr

QtObject {
  id: root

  property string socketPath: ""
  property var agents: []
  property bool online: false
  property bool refreshPending: false
  property int requestSequence: 0
  property int reconnectDelayMs: 1000
  property var requestQueue: []
  property var activeRequest: null
  property bool commandBusy: false
  property string subscribedPaneKey: ""

  readonly property var counts: Herdr.counts(agents)
  readonly property var sortedAgents: Herdr.sortedAgents(agents)
  readonly property var attentionAgent: Herdr.attentionAgent(agents)

  signal focusSucceeded(string target)
  signal protocolError(string message)

  function requestId(kind) {
    requestSequence++
    return "omarchy-herdr:" + Date.now() + ":" + requestSequence + ":" + kind
  }

  function enqueue(method, params, kind) {
    var next = requestQueue.slice()
    next.push({ method: method, params: params || {}, kind: kind, id: requestId(kind) })
    requestQueue = next
    startNextRequest()
  }

  function startNextRequest() {
    if (commandBusy || requestQueue.length === 0 || socketPath === "") return
    var next = requestQueue.slice()
    activeRequest = next.shift()
    requestQueue = next
    commandBusy = true
    commandSocket.connected = true
  }

  function sendActiveRequest() {
    if (!commandSocket.connected || !activeRequest) return
    commandTimeout.restart()
    commandSocket.write(JSON.stringify({
      id: activeRequest.id,
      method: activeRequest.method,
      params: activeRequest.params
    }) + "\n")
    commandSocket.flush()
  }

  function finishRequest() {
    commandTimeout.stop()
    activeRequest = null
    commandBusy = false
    commandSocket.connected = false
    commandKick.restart()
  }

  function refresh() {
    if (refreshPending) return
    refreshPending = true
    enqueue("agent.list", {}, "list")
  }

  function focusAgent(agent) {
    var target = Herdr.targetFor(agent)
    if (target !== "") enqueue("agent.focus", { target: target }, "focus:" + target)
  }

  function focusAttention() {
    focusAgent(attentionAgent)
  }

  function reconnect() {
    reconnectTimer.stop()
    subscriptionRetry.stop()
    commandSocket.connected = false
    subscriptionSocket.connected = false
    activeRequest = null
    commandBusy = false
    requestQueue = []
    refreshPending = false
    agents = []
    online = false
    reconnectDelayMs = 1000
    reconnectKick.restart()
  }

  function scheduleReconnect() {
    commandTimeout.stop()
    online = false
    refreshPending = false
    activeRequest = null
    commandBusy = false
    requestQueue = []
    commandSocket.connected = false
    if (!reconnectTimer.running) reconnectTimer.start()
  }

  function handleCommandLine(line) {
    var payload
    try {
      payload = JSON.parse(String(line))
    } catch (error) {
      protocolError("Herdr returned invalid JSON")
      scheduleReconnect()
      return
    }

    if (!activeRequest || String(payload.id || "") !== activeRequest.id) return
    var kind = activeRequest.kind
    if (payload.error) {
      protocolError(String(payload.error.message || "Herdr request failed"))
      if (kind === "list") scheduleReconnect()
      else finishRequest()
      return
    }

    if (kind === "list") {
      refreshPending = false
      var result = payload.result || {}
      agents = Array.isArray(result.agents) ? result.agents : []
      online = true
      reconnectDelayMs = 1000
      reconnectTimer.stop()
      rebuildSubscription()
    } else if (kind.indexOf("focus:") === 0) {
      focusSucceeded(kind.slice(6))
    }
    finishRequest()
  }

  function rebuildSubscription() {
    var nextKey = Herdr.paneKey(agents)
    if (subscriptionSocket.connected && nextKey === subscribedPaneKey) return
    subscribedPaneKey = nextKey
    subscriptionSocket.connected = false
    subscriptionKick.restart()
  }

  function sendSubscription() {
    if (!subscriptionSocket.connected) return
    var payload = {
      id: requestId("subscribe"),
      method: "events.subscribe",
      params: { subscriptions: Herdr.subscriptions(agents) }
    }
    subscriptionSocket.write(JSON.stringify(payload) + "\n")
    subscriptionSocket.flush()
  }

  function handleSubscriptionLine(line) {
    var payload
    try {
      payload = JSON.parse(String(line))
    } catch (error) {
      protocolError("Herdr event stream returned invalid JSON")
      return
    }
    if (payload.error) {
      protocolError(String(payload.error.message || "Herdr subscription failed"))
      subscriptionSocket.connected = false
      subscriptionRetry.restart()
    } else if (!payload.id) {
      refresh()
    }
  }

  onSocketPathChanged: reconnect()

  property Socket commandSocket: Socket {
    path: root.socketPath
    parser: SplitParser { onRead: function(line) { root.handleCommandLine(line) } }

    // Herdr intentionally closes request sockets after one response. A short
    // timeout, rather than PeerClosedError, distinguishes that normal EOF from
    // a request that never answered.
    onConnectedChanged: if (connected) root.sendActiveRequest()
    onError: function(errorCode) {
      // PeerClosedError after a valid one-shot response is normal and arrives
      // while the response timeout is active. A connect failure never starts
      // that timer and should enter bounded reconnect immediately.
      if (root.commandBusy && !root.commandTimeout.running) root.scheduleReconnect()
    }
  }

  property Socket subscriptionSocket: Socket {
    path: root.socketPath
    parser: SplitParser { onRead: function(line) { root.handleSubscriptionLine(line) } }

    onConnectedChanged: {
      if (connected) root.sendSubscription()
      else if (root.online && !root.subscriptionRetry.running && !root.subscriptionKick.running)
        root.subscriptionRetry.start()
    }
    onError: function(errorCode) {
      if (root.online && !root.subscriptionRetry.running) root.subscriptionRetry.start()
    }
  }

  property Timer commandTimeout: Timer {
    interval: 3000
    repeat: false
    onTriggered: root.scheduleReconnect()
  }

  property Timer reconnectTimer: Timer {
    interval: root.reconnectDelayMs
    repeat: false
    onTriggered: {
      root.reconnectDelayMs = Math.min(root.reconnectDelayMs * 2, 30000)
      root.refresh()
    }
  }

  property Timer reconnectKick: Timer {
    // Socket.path changes only take effect after the prior connection is fully
    // down. One short tick keeps session/settings switches from reconnecting
    // to the old path.
    interval: 50
    repeat: false
    onTriggered: root.refresh()
  }

  property Timer commandKick: Timer {
    interval: 0
    repeat: false
    onTriggered: root.startNextRequest()
  }

  property Timer subscriptionKick: Timer {
    interval: 0
    repeat: false
    onTriggered: if (root.online && root.socketPath !== "") root.subscriptionSocket.connected = true
  }

  property Timer subscriptionRetry: Timer {
    interval: 1000
    repeat: false
    onTriggered: if (root.online && root.socketPath !== "") root.subscriptionSocket.connected = true
  }

  Component.onCompleted: if (socketPath !== "") refresh()
}
