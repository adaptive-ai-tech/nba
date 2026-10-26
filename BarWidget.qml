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
  property real nowSecs: Date.now() / 1000

  // Per-instance setting from shell.json: "summary" (default, one compact widget) or
  // "strip" (every live game laid out inline; a small 🏀 icon when nothing is live).
  readonly property string mode: setting("mode", "summary")
  readonly property bool strip: mode === "strip"
  readonly property var stripGames: Model.stripGames(root.scores, root.nowSecs, setting("finalSeconds", 600))

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

  Timer { interval: 6000; running: true; repeat: true; onTriggered: { root.rot++; root.nowSecs = Date.now() / 1000 } }

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
    // Full scores only while a game is live; otherwise collapse to a small icon (click still opens the schedule).
    // Strip: all live games inline; a small icon when idle so the dropdown is always one click away.
    text: root.strip
      ? (root.stripGames.length ? "🏀 " + Model.stripText(root.stripGames, root.rot, setting("maxGames", 4)) : "🏀")
      : ((root.scores && root.scores.live && Model.barText(root.scores, root.rot)) ? "🏀 " + Model.barText(root.scores, root.rot) : "🏀")
    tooltipText: Model.tooltipText(root.scores)
    onPressed: function(buttonCode) { if (buttonCode === Qt.LeftButton) root.toggle() }
  }
}
