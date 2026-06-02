import Quickshell.Io
import QtQuick

// Shell-polled stats only (CPU/RAM/WiFi/temp — everything else uses native APIs)
Item {
    id: root
    visible: false

    property int    cpuPct:    0
    property int    ramUsedMb: 0
    property int    ramTotalMb: 1
    property real   cpuTemp:   0
    property int    wifiSignal: 0
    property string wifiSsid:  ""
    property var    _prevCpu:  []

    // CPU history for sparklines (last 40 samples)
    property var cpuHistory: []

    Process {
        id: cpuProc
        command: ["sh", "-c", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                var f = data.trim().split(" ").map(Number)
                if (root._prevCpu.length === 7) {
                    var idle  = f[3], total  = f.reduce((a,b)=>a+b,0)
                    var pIdle = root._prevCpu[3], pTotal = root._prevCpu.reduce((a,b)=>a+b,0)
                    var dt = total - pTotal
                    root.cpuPct = dt > 0 ? Math.round((1-(idle-pIdle)/dt)*100) : 0
                    var hist = root.cpuHistory.slice()
                    hist.push(root.cpuPct)
                    if (hist.length > 40) hist.shift()
                    root.cpuHistory = hist
                }
                root._prevCpu = f
            }
        }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "free -m | awk 'NR==2{print $3, $2}'"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                root.ramUsedMb  = parseInt(p[0]) || 0
                root.ramTotalMb = parseInt(p[1]) || 1
            }
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", "sensors 2>/dev/null | awk '/^CPU:/{gsub(/[^0-9.]/,\"\",$2); print $2; exit}'"]
        stdout: SplitParser {
            onRead: data => { var v = parseFloat(data); if (v > 0) root.cpuTemp = v }
        }
    }

    Process {
        id: wifiSigProc
        command: ["sh", "-c", "awk 'NR==3{gsub(/\\./,\"\",$3); v=int($3*100/70); print (v>100?100:v)}' /proc/net/wireless 2>/dev/null || echo 0"]
        stdout: SplitParser { onRead: data => root.wifiSignal = parseInt(data) || 0 }
    }

    Process {
        id: wifiSsidProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}'"]
        stdout: SplitParser { onRead: data => root.wifiSsid = data.trim() }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuProc.running     = true
            ramProc.running     = true
            tempProc.running    = true
            wifiSigProc.running = true
            wifiSsidProc.running= true
        }
    }
}
