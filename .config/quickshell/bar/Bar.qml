import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    required property string activePanel
    signal openPanel(string name)
    signal showOsd(string kind, real value)
    signal showToast(string app, string title, string body)

    // ── Colors ───────────────────────────────────────────────────────────
    readonly property color crust:    "#11111b"
    readonly property color mantle:   "#181825"
    readonly property color base:     "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay2: "#9399b2"
    readonly property color subtext0: "#a6adc8"
    readonly property color subtext1: "#bac2de"
    readonly property color text:     "#cdd6f4"
    readonly property color pink:     "#f38ba8"
    readonly property color maroon:   "#eba0ac"
    readonly property color green:    "#a6e3a1"
    readonly property color yellow:   "#f9e2af"
    readonly property color peach:    "#fab387"
    readonly property color red:      "#f38ba8"
    readonly property color mauve:    "#cba6f7"

    // Accent — moonlight mauve (fresh aesthetic)
    readonly property color accent:     mauve
    readonly property color accentSoft: Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.16)

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    // ── Native data ──────────────────────────────────────────────────────
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    readonly property real volPct:    Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
    readonly property bool volMuted:  Pipewire.defaultAudioSink?.audio?.muted ?? false
    readonly property bool btPowered: Bluetooth.defaultAdapter?.enabled ?? false

    // ── Battery via sysfs ────────────────────────────────────────────────
    property real battPct:      100
    property bool battCharging: false
    property int updateCount: 0
    property int pacmanUpdateCount: 0
    property int aurUpdateCount: 0
    property string aurHelper: ""
    property bool recordingActive: false
    property bool tempWarned: false

    Process {
        id: battProc
        command: ["sh", "-c", "paste <(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100) <(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown)"]
        stdout: SplitParser {
            onRead: d => {
                var p = d.trim().split("\t")
                if (p.length >= 2) {
                    var n = parseInt(p[0])
                    if (!isNaN(n)) root.battPct = n
                    var s = p[1].trim()
                    root.battCharging = (s === "Charging" || s === "Full")
                }
            }
        }
        running: true
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: battProc.running = true }

    // ── Shell-polled stats (CPU/RAM/WiFi) ────────────────────────────────
    SystemStats { id: sysStats }

    // ── Rofi via Hyprland dispatch (gets proper Wayland env) ─────────────
    Process { id: rofiProc; command: ["hyprctl", "dispatch", "exec", "rofi -show combi"] }

    Process {
        id: updateProc
        command: ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then p=$(checkupdates 2>/dev/null | wc -l); else p=$(pacman -Qu 2>/dev/null | wc -l); fi; if command -v paru >/dev/null 2>&1; then h=paru; a=$(paru -Qua 2>/dev/null | wc -l); elif command -v yay >/dev/null 2>&1; then h=yay; a=$(yay -Qua 2>/dev/null | wc -l); else h=; a=0; fi; printf '%s %s %s\\n' \"$p\" \"$a\" \"$h\""]
        stdout: SplitParser {
            onRead: d => {
                var p = d.trim().split(/\s+/)
                root.pacmanUpdateCount = parseInt(p[0]) || 0
                root.aurUpdateCount = parseInt(p[1]) || 0
                root.aurHelper = p.length >= 3 ? p[2] : ""
                root.updateCount = root.pacmanUpdateCount + root.aurUpdateCount
            }
        }
    }
    Timer {
        interval: 1800000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: updateProc.running = true
    }
    // Wake detector: QML timers pause during suspend, so on resume the
    // wall-clock jumps far more than the tick interval. When it does, the
    // machine just woke from sleep -> refresh everything immediately instead
    // of waiting out each widget's own poll interval.
    Timer {
        property double last: Date.now()
        interval: 30000; running: true; repeat: true
        onTriggered: {
            var now = Date.now()
            if (now - last > interval * 3) {
                battProc.running = true
                recordingProc.running = true
                sysStats.refresh()
                updateRecheck.restart()
            }
            last = now
        }
    }
    // Debounce: re-check a few seconds after a pacman transaction settles.
    Timer {
        id: updateRecheck
        interval: 4000; repeat: false
        onTriggered: updateProc.running = true
    }
    // Re-run the check whenever pacman writes to its log (install/upgrade/remove).
    FileView {
        path: "/var/log/pacman.log"
        watchChanges: true
        onFileChanged: updateRecheck.restart()
    }

    Process {
        id: recordingProc
        command: ["sh", "-c", "pgrep -x 'obs|wf-recorder|gpu-screen-recorder|kooha|simplescreenrecorder' >/dev/null && echo 1 || echo 0"]
        stdout: SplitParser { onRead: d => root.recordingActive = d.trim() === "1" }
    }
    // Recording is a rarely-toggled background status; 10s keeps pgrep (~26ms)
    // off the hot path without a noticeable delay on the indicator.
    Timer {
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: recordingProc.running = true
    }

    Timer {
        interval: 10000; running: true; repeat: true
        onTriggered: {
            if (sysStats.cpuTemp >= 75 && !root.tempWarned) {
                root.showToast("Moonlit", "Temperature warning", "CPU is " + Math.round(sysStats.cpuTemp) + "C")
                root.tempWarned = true
            } else if (sysStats.cpuTemp < 68) {
                root.tempWarned = false
            }
        }
    }

    // ── Window setup ─────────────────────────────────────────────────────
    anchors { top: true; left: true; right: true }
    exclusiveZone: implicitHeight
    implicitHeight: 42
    color: "transparent"

    WheelHandler {
        onWheel: ev => {
            var s = ev.angleDelta.y > 0 ? 0.05 : -0.05
            var v = Math.max(0, Math.min(1, (Pipewire.defaultAudioSink?.audio?.volume ?? 0) + s))
            if (Pipewire.defaultAudioSink?.audio) {
                Pipewire.defaultAudioSink.audio.volume = v
                root.showOsd("volume", Math.round(v * 100))
            }
        }
    }

    Item {
        anchors.fill: parent

        // ── LEFT ISLAND ──────────────────────────────────────────────────
        Island {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
            implicitWidth: leftRow.implicitWidth + 20

            RowLayout {
                id: leftRow
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                spacing: 7

            // ── LEFT ─────────────────────────────────────────────────────
            // Arch Linux logo — nf-linux-archlinux 
            Item {
                implicitWidth: 38; implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.activePanel === "launcher" ? root.accent : root.maroon
                    font { pixelSize: 26; family: root.nfFont }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: rofiProc.running = true
                }
            }

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                barColors: root
            }

            // Window title
            Item {
                implicitHeight: 28
                implicitWidth: Math.min(titleRow.implicitWidth + 26, 280)
                Layout.alignment: Qt.AlignVCenter
                visible: Hyprland.activeToplevel !== null

                Rectangle { anchors.fill: parent; radius: 999; color: Qt.rgba(0x11/255,0x11/255,0x1b/255,0.5) }

                RowLayout {
                    id: titleRow
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 13; rightMargin: 13 }
                    spacing: 8
                    Text {
                        text: {
                            var t = Hyprland.activeToplevel?.title ?? ""
                            if (t.toLowerCase().includes("firefox")) return ""
                            if (t.toLowerCase().includes("discord")) return "󱏮"
                            if (t.toLowerCase().includes("code"))    return "󰅴"
                            if (t.toLowerCase().includes("spotify")) return ""
                            return ""
                        }
                        color: root.overlay2
                        font { pixelSize: 14; family: root.nfFont }
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: Hyprland.activeToplevel?.title ?? "Desktop"
                        color: root.text
                        font { pixelSize: 12; bold: true; family: root.nfFont }
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            }
        }

        // ── CENTER ISLAND — the moon ─────────────────────────────────────
        Island {
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
            implicitWidth: moonRow.implicitWidth + 26
            // keep the island solid dark so the clock stays readable;
            // signal "open" with a bright mauve border, not a see-through fill
            color: Qt.rgba(0x18/255, 0x18/255, 0x25/255, 0.72)
            border.color: root.activePanel === "cal"
                        ? Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.65)
                        : Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
            Behavior on border.color { ColorAnimation { duration: 160 } }

            RowLayout {
                id: moonRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: ""
                    color: root.accent
                    font { pixelSize: 14; family: root.nfFont }
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    id: clockTxt
                    color: root.text
                    font { pixelSize: 13; bold: true; family: root.nfFont }
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: clockTxt.text = Qt.formatDateTime(new Date(), "hh:mm")
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPanel("cal")
            }
        }

        // ── RIGHT ISLAND ─────────────────────────────────────────────────
        Island {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
            implicitWidth: rightRow.implicitWidth + 20

            RowLayout {
                id: rightRow
                anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 10 }
                spacing: 7
            BarMod {
                icon: ""; label: "RAM"
                value: (sysStats.ramUsedMb / 1024).toFixed(1) + "G"
                active: root.activePanel === "sysmon"
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: ""; label: "CPU"
                value: sysStats.cpuPct + "%"
                active: root.activePanel === "sysmon"
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: "󰔏"; label: ""
                value: Math.round(sysStats.cpuTemp) + "C"
                iconSize: 15
                iconColor: root.peach
                visible: sysStats.cpuTemp >= 75
                active: true
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: root.battCharging ? "󰂄" : (root.battPct > 20 ? "󰁹" : "󰁺")
                label: ""
                value: root.battPct + "%"
                iconSize: 14
                iconColor: root.battCharging ? root.green
                         : root.battPct <= 20 ? root.red : root.subtext0
                active: root.activePanel === "sysmon"
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: "󰤨"; label: ""
                value: sysStats.wifiSsid !== "" ? sysStats.wifiSsid : (sysStats.wifiSignal + "%")
                active: root.activePanel === "net"
                barColors: root
                onClicked: root.openPanel("net")
            }

            BarMod {
                icon: "󰑓"; label: ""
                value: root.updateCount.toString()
                iconSize: 24
                iconColor: root.mauve
                visible: root.updateCount > 0
                barColors: root
                onClicked: root.showToast(
                    "Moonlit",
                    "Updates available",
                    root.aurHelper !== ""
                        ? root.pacmanUpdateCount + " pacman and " + root.aurUpdateCount + " AUR updates are waiting when you have time <3"
                        : root.pacmanUpdateCount + " pacman updates are waiting when you have time <3"
                )
            }

            Rectangle { width: 1; height: 18; color: Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.12); Layout.alignment: Qt.AlignVCenter }

            TrayBtn {
                icon: "󰕧"
                iconSize: 19
                iconColor: root.recordingActive ? root.red : root.overlay0
                visible: root.recordingActive
                active: true
                barColors: root
                onClicked: root.showToast("Moonlit", "Recording active", "A screen recording app is currently running")
            }

            // Bluetooth
            TrayBtn {
                icon: "󰂯"
                iconSize: 17
                iconColor: root.btPowered ? root.mauve : root.overlay0
                active: root.activePanel === "bt"
                barColors: root
                onClicked: root.openPanel("bt")
            }

            // Volume — nf-md-volume_high
            TrayBtn {
                icon: (root.volMuted || root.volPct === 0) ? "󰖁" : "󰕾"
                active: root.activePanel === "audio"
                barColors: root
                onClicked: root.openPanel("audio")
            }

            // Clipboard — nf-md-content_copy
            TrayBtn {
                icon: ""
                iconSize: 28
                active: root.activePanel === "clip"
                barColors: root
                onClicked: root.openPanel("clip")
            }

            Rectangle { width: 1; height: 18; color: Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.12); Layout.alignment: Qt.AlignVCenter }

            Tray { barColors: root; Layout.alignment: Qt.AlignVCenter }

            // Settings — ⚙ gear (U+2699)
            TrayBtn {
                icon: ""
                active: root.activePanel === "qs"
                barColors: root
                onClicked: root.openPanel("qs")
            }

            // Power — nf-fa-power_off
            TrayBtn {
                icon: ""
                iconColor: root.maroon
                barColors: root
                onClicked: root.openPanel("power")
                activeHoverColor: root.accentSoft
            }
            }
        }
    }

    // ── Inline components ────────────────────────────────────────────────

    // Floating pill "island" — the fresh-aesthetic module silhouette
    component Island: Rectangle {
        implicitHeight: 34
        radius: height / 2
        color: Qt.rgba(0x18/255, 0x18/255, 0x25/255, 0.72)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
    }

    component BarMod: Item {
        property string icon:      ""
        property string label:     ""
        property string value:     ""
        property color  iconColor: barColors.subtext0
        property bool   active:    false
        property int    iconSize:  22
        property var    barColors
        signal clicked()

        implicitHeight: 28
        implicitWidth:  modRow.implicitWidth + 22
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent; radius: 999
            color: parent.active ? root.accentSoft
                 : modHov.containsMouse ? Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.07)
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        RowLayout {
            id: modRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                text: parent.parent.icon
                color: parent.parent.iconColor
                font { pixelSize: parent.parent.iconSize; family: root.nfFont }
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: parent.parent.label
                visible: parent.parent.label !== ""
                color: root.overlay2
                font { pixelSize: 10; family: root.nfFont }
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                text: parent.parent.value
                color: parent.parent.active ? root.accent : root.text
                font { pixelSize: 11; bold: true; family: root.nfFont }
                Layout.alignment: Qt.AlignVCenter
            }
        }

        MouseArea {
            id: modHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component TrayBtn: Item {
        property string icon:             ""
        property color  iconColor:        barColors.subtext0
        property bool   active:           false
        property int    iconSize:         24
        property var    barColors
        property color  activeHoverColor: Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.07)
        signal clicked()

        implicitWidth: 32; implicitHeight: 32
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.fill: parent; radius: 9
            color: parent.active ? root.accentSoft
                 : btnHov.containsMouse ? parent.activeHoverColor
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.active ? root.accent : parent.iconColor
            font { pixelSize: parent.iconSize; family: root.nfFont }
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            id: btnHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
