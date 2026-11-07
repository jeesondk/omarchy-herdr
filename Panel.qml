import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Live Herdr session state: one bar icon plus a popup listing workspaces,
// tabs and panes with the agent detected in each. State comes from
// omarchy-herdr-state, which reads `herdr api snapshot` and falls back to
// `herdr pane process-info` for agents Herdr itself doesn't recognize.
Panel {
  id: root
  moduleName: "jesper.herdr"
  ipcTarget: "jesper.herdr"

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  property var state: ({ serverUp: false, version: "", workspaces: [] })

  readonly property int refreshIntervalSec: Math.max(2, Number(setting("refreshIntervalSec", 3)))
  readonly property var workspaces: state.workspaces || []
  readonly property int agentPaneCount: {
    var n = 0
    var ws = root.workspaces
    for (var i = 0; i < ws.length; i++) {
      var tabs = ws[i].tabs || []
      for (var j = 0; j < tabs.length; j++) {
        var panes = tabs[j].panes || []
        for (var k = 0; k < panes.length; k++)
          if (root.paneAgent(panes[k]) !== "") n++
      }
    }
    return n
  }
  readonly property string heroStatus: !state.serverUp
    ? strings.t("panel.serverDown")
    : strings.tn("panel.agents", agentPaneCount).arg(Commons.I18n.formatNumber(agentPaneCount))

  function paneAgent(p) {
    return String(p.agent || p.display_agent || p.proc_agent || "")
  }

  function statusColor(status) {
    switch (String(status || "")) {
      case "working": return Commons.Color.accent
      case "blocked": return Commons.Color.urgent
      default: return Commons.Color.muted
    }
  }

  // Context usage from the agent's own status line when the process fallback
  // found it, else whatever token map Herdr carries for the pane.
  function tokenTotal(p) {
    if (Number(p.ctx_used || 0) > 0) return Number(p.ctx_used)
    var tokens = p.tokens || {}
    var total = 0
    for (var key in tokens) {
      var v = parseFloat(String(tokens[key]).replace(/[^\d.]/g, ""))
      if (isFinite(v)) total += v
    }
    return total
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  function openHerdr() {
    if (root.bar && typeof root.bar.run === "function")
      root.bar.run("omarchy launch terminal herdr")
    root.close()
  }

  function newWorkspace() {
    if (!workspaceProc.running) workspaceProc.running = true
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  // The exporter ships inside the plugin, so the install is self-contained:
  // repo root -> ~/.config/omarchy/plugins/<id>/ via `omarchy plugin add`.
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  Process {
    id: stateProc
    // Absolute paths: Quickshell's Process did not resolve bare names via PATH,
    // which left the widget on its "server down" state.
    command: ["/usr/bin/python3", root.pluginDir + "/bin/omarchy-herdr-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text || "null")
          if (parsed) root.state = parsed
        } catch (e) {}
      }
    }
  }

  Process {
    id: workspaceProc
    command: ["herdr", "workspace", "create", "--focus"]
    onExited: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    opacity: root.state.serverUp ? 1.0 : 0.5
    iconComponent: Component {
      SizedImage {
        url: Qt.resolvedUrl("assets/herdr.png")
        width: Style.bar.iconSize
        height: Style.bar.iconSize
      }
    }
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: Item {
      implicitHeight: Math.min(column.implicitHeight, Style.space(440))
      anchors.fill: parent

      Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        contentWidth: width
        clip: true

        Column {
          id: column
          width: parent.width
          spacing: Style.space(10)

          // ---------- Hero: icon · title · status ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(Style.space(28), heroLabels.implicitHeight)

            SizedImage {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              url: Qt.resolvedUrl("assets/herdr.png")
              width: Style.space(28)
              height: Style.space(28)
              opacity: root.state.serverUp ? 1.0 : 0.5
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: strings.t("panel.title")
                textFormat: Text.PlainText
                color: root.bar ? root.bar.foreground : Commons.Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.heroStatus + (root.state.version ? " · " + strings.t("panel.version").arg(root.state.version) : "")
                textFormat: Text.PlainText
                color: Commons.Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }

          // ---------- Actions ----------
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              text: strings.t("panel.openHerdr")
              iconText: ""
              tooltipText: strings.t("panel.openHerdr")
              fontSize: Style.font.caption
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.openHerdr()
            }

            Button {
              text: strings.t("panel.newWorkspace")
              iconText: ""
              tooltipText: strings.t("panel.newWorkspace")
              fontSize: Style.font.caption
              foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: root.newWorkspace()
            }
          }

          // ---------- Workspaces, tabs, panes ----------
          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.workspaces.length > 0

            Repeater {
              model: root.workspaces

              Column {
                width: parent.width
                spacing: Style.space(6)

                PanelSectionHeader {
                  width: parent.width
                  text: String(modelData.label || modelData.id || "")
                }

                Repeater {
                  model: modelData.tabs || []

                  Column {
                    width: parent.width
                    spacing: Style.space(4)

                    Text {
                      text: strings.t("panel.tab") + " " + String(modelData.label || "")
                      textFormat: Text.PlainText
                      color: Commons.Color.muted
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: modelData.focused === true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Repeater {
                      model: modelData.panes || []

                      Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Rectangle {
                          width: Style.space(8)
                          height: width
                          radius: width / 2
                          color: root.statusColor(modelData.status)
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                          text: root.paneAgent(modelData) || strings.t("panel.shell")
                          textFormat: Text.PlainText
                          color: root.bar ? root.bar.foreground : Commons.Color.foreground
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          font.bold: root.paneAgent(modelData) !== ""
                          width: Style.space(70)
                          elide: Text.ElideRight
                        }

                        Text {
                          text: String(modelData.title || modelData.id || "")
                          textFormat: Text.PlainText
                          color: Commons.Color.muted
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideRight
                          // Row children: status dot (8) + agent (70) + this title
                          // + token slot (76), plus 3 gaps of 8 between 4 children.
                          width: Math.max(0, parent.width - Style.space(8) - Style.space(70) - Style.space(76) - Style.space(8) * 3)
                        }

                        // Fixed-width slot so the title's width math is stable
                        // and the count never lands past the panel edge.
                        Text {
                          id: tokenText
                          width: Style.space(76)
                          horizontalAlignment: Text.AlignRight
                          text: root.tokenTotal(modelData) > 0
                            ? strings.t("panel.ctx").arg(Commons.I18n.formatNumber(Math.round(root.tokenTotal(modelData))))
                            : ""
                          textFormat: Text.PlainText
                          color: Commons.Color.muted
                          font.family: root.bar ? root.bar.fontFamily : Style.font.family
                          font.pixelSize: Style.font.caption
                          anchors.verticalCenter: parent.verticalCenter
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          Text {
            visible: !root.state.serverUp || root.workspaces.length === 0
            text: root.state.serverUp ? strings.t("panel.empty") : strings.t("panel.serverDown")
            textFormat: Text.PlainText
            color: Commons.Color.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            width: parent.width
          }
        }
      }
    }
  }
}
