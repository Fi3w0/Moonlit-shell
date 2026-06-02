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
    readonly property color red:      "#f38ba8"
    readonly property color mauve:    "#cba6f7"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    // ── Native data ──────────────────────────────────────────────────────
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    readonly property real volPct:    Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
    readonly property bool volMuted:  Pipewire.defaultAudioSink?.audio?.muted ?? false
    readonly property bool btPowered: Bluetooth.defaultAdapter?.enabled ?? false

    // ── Battery via sysfs ────────────────────────────────────────────────
    property real battPct:      100
    property bool battCharging: false

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
    Process { id: rofiProc; command: ["hyprctl", "dispatch", "exec", "rofi -show script"] }

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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0x18/255, 0x18/255, 0x25/255, 0.62)

        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: Qt.rgba(0,0,0,0.4)
        }

        // ── LEFT — anchored, never shifts ────────────────────────────────
        RowLayout {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 10 }
            spacing: 7

            // ── LEFT ─────────────────────────────────────────────────────
            // Arch Linux logo — nf-linux-archlinux 
            Item {
                implicitWidth: 44; implicitHeight: 38
                Layout.alignment: Qt.AlignVCenter

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: root.activePanel === "launcher" ? root.pink : root.maroon
                    font { pixelSize: 32; family: root.nfFont }
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

        // ── RIGHT — anchored right, always tight ─────────────────────────
        RowLayout {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; rightMargin: 10 }
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

            Rectangle { width: 1; height: 18; color: Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.12); Layout.alignment: Qt.AlignVCenter }

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

            Rectangle { width: 1; height: 18; color: Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.12); Layout.alignment: Qt.AlignVCenter }

            // Clock
            Item {
                implicitHeight: 28
                implicitWidth: clockTxt.implicitWidth + 20
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent; radius: 999
                    color: root.activePanel === "cal"
                           ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
                           : (clockHov.containsMouse ? Qt.rgba(0xcd/255,0xd6/255,0xf4/255,0.07) : "transparent")
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: clockTxt
                    anchors.centerIn: parent
                    color: root.activePanel === "cal" ? root.pink : root.text
                    font { pixelSize: 13; bold: true; family: root.nfFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: clockTxt.text = Qt.formatDateTime(new Date(), "hh:mm")
                    }
                }

                MouseArea {
                    id: clockHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPanel("cal")
                }
            }

            // Power — nf-fa-power_off 
            TrayBtn {
                icon: ""
                iconColor: root.maroon
                barColors: root
                onClicked: root.openPanel("power")
                activeHoverColor: Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
            }
        }
    }

    // ── Inline components ────────────────────────────────────────────────

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
            color: parent.active ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
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
                color: parent.parent.active ? root.pink : root.text
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
            color: parent.active ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
                 : btnHov.containsMouse ? parent.activeHoverColor
                 : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Text {
            anchors.centerIn: parent
            text: parent.icon
            color: parent.active ? root.pink : parent.iconColor
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
