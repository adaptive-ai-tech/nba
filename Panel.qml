import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.adaptive-ai-tech.nba"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var scores: null
  property string expanded: ""
  property bool showDonate: false
  readonly property string fam: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string donateUrl: root.scores && root.scores.donateUrl ? String(root.scores.donateUrl) : ""

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }
  // One click on a score opens that game's live page in its own app window.
  function openUrl(url, appWindow) {
    if (!/^(https|upi):\/\//.test(url)) return
    if (appWindow)
      Quickshell.execDetached(["sh", "-c",
        "if command -v omarchy-launch-webapp >/dev/null 2>&1; then exec omarchy-launch-webapp \"$1\"; else exec chromium --app=\"$1\"; fi",
        "nba-scores", url])
    else
      Quickshell.execDetached(["xdg-open", url])
    root.close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(6)

        Text {
          width: parent.width
          text: "NBA · " + (root.scores && root.scores.gameDate ? root.scores.gameDate : "today")
                + (root.scores && root.scores.updated ? "  ·  " + root.scores.updated : "")
          color: root.barForeground
          font.family: root.fam
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          visible: !root.scores || root.scores.games.length === 0
          text: !root.scores ? "No data yet. Run install.sh to start nba-scores.service."
                : (root.scores.upcoming && root.scores.upcoming.length
                   ? "No games today. Next:\n" + root.scores.upcoming.slice(0, 3).map(function (u) { return u.away + " @ " + u.home + "  " + u.start }).join("\n")
                   : "No games")
          color: root.barForeground
          font.family: root.fam
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        Repeater {
          model: root.scores ? root.scores.games : []
          delegate: Column {
            id: gameItem
            required property var modelData
            width: content.width
            spacing: Style.space(2)

            Item {
              width: parent.width
              height: row.implicitHeight + Style.space(6)

              Rectangle {
                anchors.fill: parent
                radius: Style.space(4)
                color: root.barForeground
                opacity: rowMouse.containsMouse ? 0.08 : 0
              }
              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openUrl(gameItem.modelData.url, true)
              }
              Row {
                id: row
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)
                Text {
                  width: Style.space(190)
                  text: gameItem.modelData.status === 1
                        ? gameItem.modelData.away + " @ " + gameItem.modelData.home
                        : gameItem.modelData.away + " " + gameItem.modelData.awayScore + " – " + gameItem.modelData.homeScore + " " + gameItem.modelData.home
                  color: root.barForeground
                  font.family: root.fam
                  font.pixelSize: Style.font.body
                  font.bold: gameItem.modelData.status === 2
                }
                Text {
                  width: Style.space(120)
                  text: gameItem.modelData.status === 1 ? gameItem.modelData.start : gameItem.modelData.statusText
                  color: root.barForeground
                  opacity: 0.75
                  font.family: root.fam
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  visible: !!gameItem.modelData.leaders
                  text: root.expanded === gameItem.modelData.gameId ? "▾" : "▸"
                  color: root.barForeground
                  font.family: root.fam
                  font.pixelSize: Style.font.body
                  MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expanded = (root.expanded === gameItem.modelData.gameId ? "" : gameItem.modelData.gameId)
                  }
                }
              }
            }
            Text {
              width: parent.width
              visible: root.expanded === gameItem.modelData.gameId
              text: Model.leaderText(gameItem.modelData)
              color: root.barForeground
              opacity: 0.8
              font.family: root.fam
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }

        Text {
          width: parent.width
          text: "Click a game to open it · ▸ top scorers" + (root.scores && root.scores.ok === false ? " · offline, showing last data" : "")
          color: root.barForeground
          opacity: 0.5
          font.family: root.fam
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Text {
          text: root.showDonate ? "♥ Support (hide)" : "♥ Support"
          color: root.barForeground
          opacity: donateMouse.containsMouse ? 0.9 : 0.6
          font.family: root.fam
          font.pixelSize: Style.font.caption
          font.underline: donateMouse.containsMouse
          MouseArea {
            id: donateMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showDonate = !root.showDonate
          }
        }

        Column {
          visible: root.showDonate
          width: parent.width
          spacing: Style.space(4)
          Text {
            width: parent.width
            text: "NBA Scores is free. Donations are optional: scan with any UPI app."
            color: root.barForeground
            opacity: 0.7
            font.family: root.fam
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
          Image {
            source: Qt.resolvedUrl("assets/donate-qr.jpg")
            width: Style.space(200)
            height: width * sourceSize.height / Math.max(1, sourceSize.width)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
          }
          Text {
            visible: /^upi:\/\//.test(root.donateUrl)
            text: "Open in UPI app"
            color: root.barForeground
            opacity: upiMouse.containsMouse ? 0.9 : 0.6
            font.family: root.fam
            font.pixelSize: Style.font.caption
            font.underline: upiMouse.containsMouse
            MouseArea {
              id: upiMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openUrl(root.donateUrl, false)
            }
          }
        }
      }
    }
  }
}
