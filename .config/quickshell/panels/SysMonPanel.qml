import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "../bar"

PanelWindow {
    id: root
    signal close()

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 396
    implicitHeight: smContent.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext0: "#a6adc8"
    readonly property color text:     "#cdd6f4"
    readonly property color pink:     "#f38ba8"
    readonly property color blue:     "#89b4fa"
    readonly property color mauve:    "#cba6f7"
    readonly property color teal:     "#94e2d5"
    readonly property color peach:    "#fab387"
    readonly property color maroon:   "#eba0ac"

    // Stats
    SystemStats { id: sysStats }

    // Disk usage
    property int diskPct: 0
    Process {
        command: ["sh", "-c", "df / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'"]
        stdout: SplitParser { onRead: d => root.diskPct = parseInt(d) || 0 }
        running: true
    }

    // Process list — buffer then swap atomically (no flicker)
    ListModel { id: procModel }
    property var procBuffer: []
    Process {
        id: procProc
        command: ["sh", "-c", "NCPU=$(nproc); ps aux --sort=-%cpu | awk -v nc=$NCPU 'NR>1 && NR<=7{cpu=$3/nc; if(cpu>100)cpu=100; printf \"%s %.1f %.1f\\n\", $11, cpu, $4}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "") return
                var p = data.trim().split(" ")
                if (p.length >= 3) {
                    var name = p[0].split("/").pop()
                    root.procBuffer.push({ name: name.substring(0,18), cpu: parseFloat(p[1]).toFixed(1), mem: parseFloat(p[2]).toFixed(1) })
                }
            }
        }
        onRunningChanged: {
            if (!running && root.procBuffer.length > 0) {
                procModel.clear()
                for (var i = 0; i < root.procBuffer.length; i++) procModel.append(root.procBuffer[i])
                root.procBuffer = []
            }
        }
    }

    // Net speed
    property real netRx: 0
    property real netTx: 0
    property var  _prevNet: []
    Process {
        id: netProc
        command: ["sh", "-c", "cat /proc/net/dev | awk '/wlp3s0/{print $2, $10}'"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ").map(Number)
                if (root._prevNet.length === 2) {
                    root.netRx = Math.max(0, (p[0] - root._prevNet[0]) / 1024 / 3)
                    root.netTx = Math.max(0, (p[1] - root._prevNet[1]) / 1024 / 3)
                }
                root._prevNet = p
            }
        }
    }

    onVisibleChanged: if (visible) {
        root.procBuffer = []
        procProc.running = true
    }

    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            if (root.visible) { root.procBuffer = []; procProc.running = true }
        }
    }

    Rectangle {
        id: smContent
        width: parent.width
        implicitHeight: smCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: smCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "SYSTEM MONITOR"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }
                Text { text: ""; color: root.pink; font { pixelSize: 18; family: root.nfFont } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 11

                // CPU card with sparkline
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 110; radius: 16; color: root.surface0

                    ColumnLayout {
                        anchors { fill: parent; margins: 15 }
                        spacing: 8

                        RowLayout {
                            Text { text: ""; color: root.subtext0; font { pixelSize: 14; family: root.nfFont } }
                            Text { text: "CPU"; color: root.subtext0; font { pixelSize: 12; family: root.nfFont } }
                            Item { Layout.fillWidth: true }
                            Text { text: sysStats.cpuPct + "%"; color: root.pink; font { pixelSize: 14; bold: true; family: root.nfFont } }
                            Text { text: sysStats.cpuTemp > 0 ? sysStats.cpuTemp.toFixed(0) + "°C" : ""; color: root.overlay0; font { pixelSize: 11; family: root.nfFont } }
                        }

                        // Sparkline
                        Canvas {
                            Layout.fillWidth: true; height: 48
                            property var data: sysStats.cpuHistory
                            onDataChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var d = data
                                if (!d || d.length < 2) return
                                var step = width / (d.length - 1)
                                ctx.beginPath()
                                for (var i = 0; i < d.length; i++) {
                                    var x = i * step
                                    var y = height - (d[i] / 100) * height
                                    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                                }
                                // Area fill
                                ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                                var grad = ctx.createLinearGradient(0, 0, 0, height)
                                grad.addColorStop(0, "rgba(243,139,168,0.35)")
                                grad.addColorStop(1, "rgba(243,139,168,0)")
                                ctx.fillStyle = grad; ctx.fill()
                                // Line
                                ctx.beginPath()
                                for (var j = 0; j < d.length; j++) {
                                    var lx = j * step, ly = height - (d[j] / 100) * height
                                    j === 0 ? ctx.moveTo(lx, ly) : ctx.lineTo(lx, ly)
                                }
                                ctx.strokeStyle = "#f38ba8"; ctx.lineWidth = 2; ctx.lineJoin = "round"; ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                    }
                }

                // Rings: RAM / DISK / TEMP
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 100; radius: 16; color: root.surface0

                    Row {
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: [
                                { label: "RAM",  pct: sysStats.ramTotalMb > 0 ? Math.round(sysStats.ramUsedMb / sysStats.ramTotalMb * 100) : 0,
                                  val: (sysStats.ramUsedMb/1024).toFixed(1)+"G", color: root.mauve },
                                { label: "DISK", pct: root.diskPct,
                                  val: root.diskPct + "%", color: root.teal },
                                { label: "TEMP", pct: Math.min(100, Math.round(sysStats.cpuTemp / 100 * 100)),
                                  val: sysStats.cpuTemp.toFixed(0) + "°", color: root.peach },
                            ]
                            delegate: Item {
                                required property var modelData
                                width: (396 - 32) / 3; height: 100

                                Canvas {
                                    id: ringCanvas
                                    anchors.centerIn: parent
                                    width: 80; height: 80
                                    property color col: parent.modelData.color
                                    property real  pct: parent.modelData.pct / 100
                                    onPctChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0,0,width,height)
                                        var cx = width/2, cy = height/2, r = 30
                                        // Track
                                        ctx.beginPath(); ctx.arc(cx,cy,r,0,Math.PI*2)
                                        ctx.strokeStyle = "#313244"; ctx.lineWidth = 8; ctx.stroke()
                                        // Progress
                                        ctx.beginPath()
                                        ctx.arc(cx,cy,r,-Math.PI/2,-Math.PI/2+Math.PI*2*pct)
                                        ctx.strokeStyle = col; ctx.lineWidth = 8
                                        ctx.lineCap = "round"; ctx.stroke()
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: parent.parent.modelData.val
                                        color: root.text
                                        font { pixelSize: 13; bold: true; family: root.nfFont }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: parent.parent.modelData.label
                                        color: root.overlay0
                                        font { pixelSize: 9; family: root.nfFont }
                                    }
                                }
                            }
                        }
                    }
                }

                // Network
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 52; radius: 16; color: root.surface0

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }

                        Text { text: "󰜂"; color: root.subtext0; font { pixelSize: 14; family: root.nfFont } }
                        Text { text: "Network"; color: root.subtext0; font { pixelSize: 12; family: root.nfFont } }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "↓ " + (root.netRx < 1024 ? root.netRx.toFixed(0) + " KB/s" : (root.netRx/1024).toFixed(1) + " MB/s") +
                                  "  ↑ " + (root.netTx < 1024 ? root.netTx.toFixed(0) + " KB/s" : (root.netTx/1024).toFixed(1) + " MB/s")
                            color: root.blue
                            font { pixelSize: 11; bold: true; family: root.nfFont }
                        }
                    }
                }

                // Process list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 4
                        Text { text: "Process"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } Layout.fillWidth: true }
                        Text { text: "CPU"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                        Text { text: "MEM"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                    }

                    Repeater {
                        model: procModel
                        delegate: Item {
                            required property var model
                            Layout.fillWidth: true; height: 34

                            Rectangle {
                                anchors.fill: parent; radius: 10
                                color: procHov.containsMouse ? root.surface0 : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                Text { text: model.name; color: root.text; font { pixelSize: 12; family: root.nfFont } Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: model.cpu + "%"; color: root.pink; font { pixelSize: 12; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                                Text { text: model.mem + "%"; color: root.mauve; font { pixelSize: 12; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                            }

                            MouseArea { id: procHov; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }

                Item { implicitHeight: 4 }
            }
        }
    }
}
