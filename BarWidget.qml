import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Herdr.js" as Herdr

Panel {
  id: root
  moduleName: "carlotran4.herdr"
  manageIpc: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string resolvedSocketPath: Herdr.socketPath(
    home,
    setting("session", "default"),
    setting("socketPath", "")
  )
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color surface: Color.popups.background
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.52)
  readonly property bool iconVisible: vertical || setting("showIcon", false)
  readonly property var statusColors: ({
    blocked: "#f7768e",
    done: "#9ece6a",
    working: "#7aa2f7",
    unknown: "#e0af68",
    idle: "#737aa2"
  })

  visible: iconVisible || !model.online || model.agents.length > 0
  implicitWidth: vertical ? barSize : Math.max(barSize, barContent.implicitWidth + Style.space(12))
  implicitHeight: barSize

  function tooltipText() {
    return Herdr.tooltip(model.agents, model.online, home)
  }

  function focus(agent) {
    model.focusAgent(agent)
    close()
  }

  function raiseHerdrWindow() {
    if (!setting("raiseWindow", true)) return
    var script = String(Qt.resolvedUrl("scripts/focus-herdr-window")).replace(/^file:\/\//, "")
    Quickshell.execDetached([script, String(setting("windowTitle", "herdr"))])
  }

  function open() {
    controller.show()
    if (bar && typeof bar.requestPopout === "function") bar.requestPopout(root)
  }

  function close() {
    controller.hide()
    if (bar && typeof bar.releasePopout === "function") bar.releasePopout(root)
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  HerdrModel {
    id: model
    socketPath: root.resolvedSocketPath
    onFocusSucceeded: function(target) { root.raiseHerdrWindow() }
  }

  Rectangle {
    id: button
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.opened ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(7)

      Text {
        visible: root.iconVisible
        text: "󰚩"
        color: root.foreground
        opacity: model.online ? 1 : 0.45
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        visible: !root.iconVisible && !model.online
        width: visible ? Style.space(6) : 0
        height: width
        radius: width / 2
        color: root.dim
        anchors.verticalCenter: parent.verticalCenter
      }

      Repeater {
        model: root.vertical ? [] : Herdr.STATUS_ORDER

        Row {
          required property string modelData
          readonly property int count: Number(model.counts[modelData] || 0)
          visible: count > 0
          width: visible ? implicitWidth : 0
          spacing: Style.space(3)
          anchors.verticalCenter: parent.verticalCenter

          Rectangle {
            width: Style.space(5)
            height: width
            radius: width / 2
            color: root.statusColors[modelData]
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: parent.count
            color: root.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor

      onEntered: if (root.bar) root.bar.showTooltip(button, root.tooltipText())
      onExited: if (root.bar) root.bar.hideTooltip(button)
      onClicked: function(mouse) {
        if (root.bar) root.bar.hideTooltip(button)
        if (mouse.button === Qt.RightButton) model.refresh()
        else if (mouse.button === Qt.MiddleButton) model.focusAttention()
        else root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(panelContent.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: model.focusAttention()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
          id: panelContent
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Herdr"
            meta: model.online
              ? model.agents.length + " active coding agent" + (model.agents.length === 1 ? "" : "s")
              : "Waiting for the Herdr socket"
            foreground: root.foreground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

            iconComponent: Component {
              Text {
                text: "󰚩"
                color: root.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Row {
            visible: model.agents.length > 0
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: Herdr.STATUS_ORDER

              Rectangle {
                required property string modelData
                readonly property int count: Number(model.counts[modelData] || 0)
                visible: count > 0
                width: visible ? summaryLabel.implicitWidth + Style.space(16) : 0
                height: Style.space(28)
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                border.width: 1
                border.color: root.statusColors[modelData]

                Text {
                  id: summaryLabel
                  anchors.centerIn: parent
                  text: Herdr.STATUS_ICONS[modelData] + "  " + parent.count
                  color: root.statusColors[modelData]
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
          }

          PanelSeparator {
            visible: model.agents.length > 0
            foreground: root.foreground
          }

          Column {
            visible: model.agents.length > 0
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              model: model.sortedAgents

              Rectangle {
                id: agentCard
                required property var modelData
                readonly property string status: Herdr.normalizeStatus(modelData)
                width: parent.width
                height: Style.space(66)
                radius: Style.cornerRadius
                color: agentMouse.containsMouse
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)

                Behavior on color { ColorAnimation { duration: 100 } }

                Rectangle {
                  width: Style.space(4)
                  radius: width / 2
                  color: root.statusColors[agentCard.status]
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.topMargin: Style.space(10)
                  anchors.bottomMargin: Style.space(10)
                }

                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(16)
                  anchors.right: statusText.left
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)

                  Text {
                    width: parent.width
                    text: Herdr.agentLabel(agentCard.modelData, 40)
                    color: root.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: Herdr.shortenPath(agentCard.modelData.foreground_cwd || agentCard.modelData.cwd, root.home, 48)
                    color: root.dim
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                  }
                }

                Text {
                  id: statusText
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: Herdr.STATUS_LABELS[agentCard.status]
                  color: root.statusColors[agentCard.status]
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                MouseArea {
                  id: agentMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.focus(agentCard.modelData)
                }
              }
            }
          }

          Column {
            visible: model.online && model.agents.length === 0
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              topPadding: Style.space(24)
              text: "All quiet."
              color: root.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              bottomPadding: Style.space(24)
              text: "Agents appear here as soon as Herdr detects them."
              color: root.dim
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
            }
          }

          Text {
            visible: !model.online
            width: parent.width
            topPadding: Style.space(22)
            bottomPadding: Style.space(22)
            text: "Start Herdr to reconnect automatically.\n" + root.resolvedSocketPath
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAnywhere
          }

          Text {
            visible: model.agents.length > 0
            width: parent.width
            text: "Click an agent to jump there · Enter focuses priority"
            color: root.dim
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
