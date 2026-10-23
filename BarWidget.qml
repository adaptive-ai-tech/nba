import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.adaptive-ai-tech.nba"

  property var scores: null
  property int rot: 0

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.scores = root.scores
  }
  onScoresChanged: if (panelLoader.item) panelLoader.item.scores = root.scores

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  // Reads only the local cache written by nba-scores.service; the UI never touches the network.
  FileView {
    id: cache
    path: Quickshell.env("HOME") + "/.cache/nba-scores/scores.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var d = Model.parse(cache.text())
      if (d) root.scores = d
    }
  }

  Timer { interval: 6000; running: true; repeat: true; onTriggered: root.rot++ }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "🏀 " + Model.barText(root.scores, root.rot)
    tooltipText: root.scores ? ("NBA scores · updated " + (root.scores.updated || "")) : "NBA scores: waiting for nba-scores.service"
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
  }
}
