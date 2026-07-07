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
    property bool   enabled: true

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
        // Read CPU temp straight from sysfs (~3ms) instead of `sensors` (~45ms).
        // Portable across hardware, three fallback tiers:
        //  1) hwmon by chip NAME (hwmonN isn't stable across reboots) — AMD
        //     k10temp, Intel coretemp, ARM cpu_thermal/soc_thermal, ThinkPad, acpitz
        //  2) thermal zone whose type looks like a CPU/package sensor (Intel
        //     x86_pkg_temp, ARM SoCs, …)  3) first thermal zone as last resort.
        command: ["sh", "-c", 'for n in k10temp coretemp cpu_thermal soc_thermal thinkpad acpitz; do for h in /sys/class/hwmon/*; do read -r hn < "$h/name" 2>/dev/null || continue; [ "$hn" = "$n" ] || continue; read -r t < "$h/temp1_input" 2>/dev/null || continue; [ -n "$t" ] && [ "$t" -gt 0 ] && { echo $((t/1000)); exit 0; }; done; done; for z in /sys/class/thermal/thermal_zone*; do read -r ty < "$z/type" 2>/dev/null || continue; case "$ty" in x86_pkg_temp|*cpu*|*CPU*|*pkg*|*soc*) read -r t < "$z/temp" 2>/dev/null || continue; [ -n "$t" ] && [ "$t" -gt 0 ] && { echo $((t/1000)); exit 0; }; ;; esac; done; read -r t < /sys/class/thermal/thermal_zone0/temp 2>/dev/null && [ -n "$t" ] && [ "$t" -gt 0 ] && echo $((t/1000))']
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

    // Cheap, fast-changing stats — /proc + sysfs reads, ~10ms total.
    function refreshFast() {
        cpuProc.running     = true
        ramProc.running     = true
        tempProc.running    = true
        wifiSigProc.running = true
    }
    // Everything, including the expensive nmcli SSID lookup. Used on wake.
    function refresh() {
        refreshFast()
        wifiSsidProc.running = true
    }

    // Fast tick: responsive meters, all lightweight reads.
    Timer {
        interval: 5000; running: root.enabled; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshFast()
    }
    // Slow tick: SSID rarely changes and nmcli is expensive (~20ms).
    Timer {
        interval: 30000; running: root.enabled; repeat: true; triggeredOnStart: true
        onTriggered: wifiSsidProc.running = true
    }
}
