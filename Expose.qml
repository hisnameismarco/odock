
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// App Exposé: every window of one app as a clickable thumbnail grid, the
// macOS click-and-hold behaviour. Opened from a dock item that has live
// windows (see Dock.openExpose); each card is a one-shot screencopy of the
// toplevel, and clicking one raises it and closes the grid. A click on the
// dim backdrop, Escape, or losing the focus grab closes it too. The dock is
// held open for as long as the grid is up.
Item {
  id: expose
  required property var dock

  property var windows: []
  property string title: ""
  property string screenName: ""
  property bool open: false

  // Every screen's overlay is created up front; only the dock's screen is
  // shown. Collected so the focus grab routes input to the live ones.
  property var overlayWindows: []

  function openFor(list, label, screen) {
    if (!list || list.length === 0) return
    expose.windows = list.slice()
    expose.title = String(label || "")
    expose.screenName = String(screen || "")
    expose.open = true
    expose.dock.holdForPopup()
  }

  function close() {
    if (!expose.open) return
    expose.open = false
    expose.dock.popupReleased()
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: overlay
      required property var modelData

      readonly property bool onTargetScreen: expose.screenName === ""
        || String(modelData.name || "") === expose.screenName

      // Grid geometry: up to four columns, thumbnails sized to the monitor.
      readonly property int cols: Math.min(Math.max(expose.windows.length, 1), 4)
      readonly property int cardW: {
        var usable = Number(modelData.width || 1920) * 0.86
        var gap = Style.space(18)
        var w = Math.floor((usable - gap * (cols - 1)) / cols)
        return Math.max(200, Math.min(w, 460))
      }
      readonly property int cardH: Math.round(cardW * 0.60)

      screen: modelData
      visible: expose.open && overlay.onTargetScreen
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      exclusiveZone: 0
      WlrLayershell.namespace: "omarchy-odock-expose"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      Component.onCompleted: expose.overlayWindows.push(overlay)
      Component.onDestruction: {
        var i = expose.overlayWindows.indexOf(overlay)
        if (i >= 0) expose.overlayWindows.splice(i, 1)
      }

      // Escape closes; kept behind the backdrop so it never eats a click.
      Item {
        anchors.fill: parent
        focus: overlay.visible
        Keys.onEscapePressed: expose.close()
      }

      // Dim backdrop. A click on it (i.e. anywhere not on a card) closes.
      Rectangle {
        anchors.fill: parent
        color: Util.alpha(Color.background, 0.55)

        TapHandler { onTapped: expose.close() }

        Text {
          id: headerText
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: Style.space(36)
          text: expose.title
          color: Color.popups.text
          font.family: Style.font.resolvedFamily
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        Rectangle {
          id: closeBtn
          readonly property int side: Math.round(Style.font.heading * 1.9)
          width: side
          height: side
          radius: height / 2
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.space(24)
          color: closeHover.hovered ? Util.alpha(Color.accent, 0.25) : "transparent"
          border.width: 1
          border.color: Util.alpha(Color.popups.text, 0.35)

          Text {
            anchors.centerIn: parent
            text: "\u2715"
            color: Color.popups.text
            font.family: Style.font.resolvedFamily
            font.pixelSize: Style.font.bodySmall
          }

          HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: expose.close() }
        }

        Grid {
          id: grid
          anchors.centerIn: parent
          columns: overlay.cols
          spacing: Style.space(18)

          Repeater {
            model: expose.windows

            delegate: Rectangle {
              id: card
              required property var modelData

              width: overlay.cardW
              height: overlay.cardH + cardTitle.implicitHeight + Style.space(12)
              radius: Style.cornerRadius
              color: Util.alpha(Color.popups.background, 0.92)
              border.width: 1
              border.color: cardHover.hovered
                ? Color.accent
                : Util.alpha(Color.popups.border, 0.5)

              Rectangle {
                id: thumbFrame
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(6)
                height: overlay.cardH
                radius: Math.max(0, Style.cornerRadius - Style.space(4))
                color: Util.alpha(Color.background, 0.6)
                clip: true

                Text {
                  anchors.centerIn: parent
                  visible: !thumb.hasContent
                  text: card.modelData.appId || ""
                  color: Util.alpha(Color.popups.text, 0.5)
                  font.family: Style.font.resolvedFamily
                  font.pixelSize: Style.font.bodySmall
                }

                ScreencopyView {
                  id: thumb
                  anchors.fill: parent
                  captureSource: card.modelData
                  live: false
                  paintCursor: false
                }
              }

              Text {
                id: cardTitle
                anchors.top: thumbFrame.bottom
                anchors.topMargin: Style.space(5)
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - Style.space(12)
                text: String(card.modelData.title || card.modelData.appId || "")
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: Color.popups.text
                font.family: Style.font.resolvedFamily
                font.pixelSize: Style.font.bodySmall
              }

              HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }

              TapHandler {
                onTapped: {
                  if (card.modelData.setMinimized) card.modelData.setMinimized(false)
                  card.modelData.activate()
                  expose.close()
                }
              }
            }
          }
        }
      }
    }
  }
}
