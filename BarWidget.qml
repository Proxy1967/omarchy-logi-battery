import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "proxy.logi-battery"

  // `logi-battery` asks the mouse for its discharge level over HID++, which is
  // the percentage G HUB shows. The kernel knows that number too but doesn't
  // publish it, so sysfs only ever offers the coarse level — kept here as the
  // fallback for when the mouse is asleep or the hidraw ACL is missing.
  property string deviceName: ""
  property int percent: -1
  property string level: ""

  readonly property bool low: percent >= 0 ? percent <= 20
                                           : (level === "Low" || level === "Critical")
  readonly property string levelGlyph: ({
    "Full": "󰁹",
    "High": "󰂁",
    "Normal": "󰁾",
    "Low": "󰁻",
    "Critical": "󰂃"
  })[level] || "󰂑"

  readonly property string reader: String(Qt.resolvedUrl("logi-battery")).replace("file://", "")

  function refresh() {
    if (!readProc.running) readProc.running = true
  }

  visible: percent >= 0 || level !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: readProc
    command: [root.reader]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text).split("\n")[0].split("\t")
        if (parts.length < 3) {
          root.deviceName = ""
          root.percent = -1
          root.level = ""
          return
        }
        root.deviceName = parts[0]
        root.percent = parts[1] === "" ? -1 : parseInt(parts[1])
        root.level = parts[2]
      }
    }
  }

  // The reading moves in coarse steps over weeks, and every poll briefly wakes
  // the mouse's radio, so there is nothing to gain by asking often.
  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // A vertical bar has no room for the mouse glyph beside the reading.
    text: {
      var reading = root.percent >= 0 ? root.percent + "%" : root.levelGlyph
      return root.vertical ? (root.percent >= 0 ? String(root.percent) : root.levelGlyph)
                           : "󰍽 " + reading
    }
    fontSize: Style.font.caption
    tooltipText: {
      var name = root.deviceName || "Mouse"
      if (root.percent >= 0) return name + " — battery " + root.percent + "%"
      return name + " — battery " + (root.level || "unknown")
    }
    active: root.low
    pressable: false
  }
}
