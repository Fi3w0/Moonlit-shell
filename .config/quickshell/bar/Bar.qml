import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../services"

PanelWindow {
    id: root

    required property string activePanel
    // Machine-wide stats/status poller, owned by shell.qml and shared by every
    // monitor's bar (battery, updates, recording, temp — polled once, not once
    // per screen). See the `sharedSys` object in shell.qml.
    required property var shared
    signal openPanel(string name)
    signal showOsd(string kind, real value)
    signal showToast(string app, string title, string body)

    // ── Colors ───────────────────────────────────────────────────────────
    readonly property color crust:    Config.crust
    readonly property color mantle:   Config.mantle
    readonly property color base:     Config.base
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color surface2: Config.surface2
    readonly property color overlay0: Config.overlay0
    readonly property color overlay2: Config.overlay2
    readonly property color subtext0: Config.subtext0
    readonly property color subtext1: Config.subtext1
    readonly property color text:     Config.text
    readonly property color pink:     Config.pink
    readonly property color maroon:   Config.maroon
    readonly property color green:    Config.green
    readonly property color yellow:   Config.yellow
    readonly property color peach:    Config.peach
    readonly property color red:      Config.red
    readonly property color mauve:    Config.mauve

    // Accent — moonlight mauve, live from Config (moonlit-settings app)
    readonly property color accent:     Config.accent
    readonly property color accentSoft: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
    // Arch logo color — independent knob, defaults to the original maroon.
    readonly property color archLogo:   Config.archLogoColor

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    // ── Native data ──────────────────────────────────────────────────────
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    readonly property real volPct:    Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100)
    readonly property bool volMuted:  Pipewire.defaultAudioSink?.audio?.muted ?? false
    readonly property bool btPowered: Bluetooth.defaultAdapter?.enabled ?? false

    // ── Machine-wide stats + status ──────────────────────────────────────
    // Battery, update counts, recording and the CPU-temp warning are polled
    // exactly once in shell.qml (see `sharedSys`) and bound here, so a
    // multi-monitor setup doesn't run N copies of every poll or fire a toast
    // per screen. Only rofi (a per-bar launcher) stays local.
    readonly property real   battPct:           shared.battPct
    readonly property bool   battCharging:       shared.battCharging
    readonly property int    updateCount:        shared.updateCount
    readonly property int    pacmanUpdateCount:  shared.pacmanUpdateCount
    readonly property int    aurUpdateCount:     shared.aurUpdateCount
    readonly property string aurHelper:          shared.aurHelper
    readonly property bool   recordingActive:    shared.recordingActive
    readonly property var    sysStats:           shared.stats

    // ── Rofi via Hyprland dispatch (gets proper Wayland env) ─────────────
    Process { id: rofiProc; command: ["hyprctl", "dispatch", "exec", "rofi -show combi"] }

    // ── Window setup ─────────────────────────────────────────────────────
    // barPosition drives the anchoring: top = horizontal strip, left/right =
    // vertical side bar. Reserve height (top) or width (side) accordingly.
    readonly property bool vertical: Config.barPosition === "left" || Config.barPosition === "right"
    anchors.top: true
    anchors.bottom: Config.barPosition !== "top"
    anchors.left: Config.barPosition !== "right"
    anchors.right: Config.barPosition !== "left"
    exclusiveZone: root.vertical ? implicitWidth : implicitHeight
    implicitHeight: 42
    implicitWidth: 46
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

    Loader {
        anchors.fill: parent
        sourceComponent: root.vertical
                       ? (Config.barStyle === "classic" ? classicVLayout : islandsVLayout)
                       : (Config.barStyle === "classic" ? classicLayout : islandsLayout)
    }

    // ── Vertical side-bar layout (barPosition left/right) ────────────────
    // Three stacked pill islands: logo+workspaces (top), moon-clock (center),
    // stats+controls+power (bottom). Icon-only — values live in the panels.
    Component {
        id: islandsVLayout
        Item {
            anchors.fill: parent

            // TOP — logo + workspaces
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 8 }
                width: 34; radius: width / 2
                implicitHeight: vTopCol.implicitHeight + 14
                height: implicitHeight
                color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)
                border.width: 1
                border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)

                ColumnLayout {
                    id: vTopCol
                    anchors.centerIn: parent
                    spacing: 6
                    TrayBtn {
                        icon: String.fromCodePoint(0xf303)
                        iconColor: root.archLogo
                        iconSize: 20; barColors: root
                        onClicked: rofiProc.running = true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Workspaces { vertical: true; barColors: root; Layout.alignment: Qt.AlignHCenter }
                }
            }

            // CENTER — moon-clock (moon over HH over MM)
            Rectangle {
                anchors.centerIn: parent
                width: 34; radius: width / 2
                implicitHeight: vClockCol.implicitHeight + 16
                height: implicitHeight
                color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)
                border.width: 1
                border.color: root.activePanel === "cal"
                            ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.65)
                            : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
                Behavior on border.color { ColorAnimation { duration: 160 } }

                ColumnLayout {
                    id: vClockCol
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        text: String.fromCodePoint(0xf186)
                        color: root.accent
                        font { pixelSize: 13; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        id: vClockH
                        color: root.text
                        font { pixelSize: 13; bold: true; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        id: vClockM
                        color: root.overlay2
                        font { pixelSize: 13; bold: true; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                        Timer {
                            interval: 1000; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                var now = new Date()
                                vClockH.text = Qt.formatDateTime(now, Config.clock24h ? "HH" : "hh")
                                vClockM.text = Qt.formatDateTime(now, "mm")
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPanel("cal")
                }
            }

            // BOTTOM — stats + controls + power
            Rectangle {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 8 }
                width: 34; radius: width / 2
                implicitHeight: vBotCol.implicitHeight + 14
                height: implicitHeight
                color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)
                border.width: 1
                border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)

                ColumnLayout {
                    id: vBotCol
                    anchors.centerIn: parent
                    spacing: 3

                    TrayBtn { icon: String.fromCodePoint(0xf4bc); iconSize: 17; active: root.activePanel === "sysmon"; barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn { icon: String.fromCodePoint(0xe266); iconSize: 15; active: root.activePanel === "sysmon"; barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn {
                        icon: root.battCharging ? String.fromCodePoint(0xf0084) : (root.battPct > 20 ? String.fromCodePoint(0xf0079) : String.fromCodePoint(0xf007a))
                        iconSize: 15
                        iconColor: root.battCharging ? root.green : (root.battPct <= 20 ? root.red : root.subtext0)
                        visible: Config.showBattery
                        barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter
                    }
                    TrayBtn { icon: String.fromCodePoint(0xf0928); iconSize: 15; active: root.activePanel === "net"; barColors: root; onClicked: root.openPanel("net"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn {
                        icon: String.fromCodePoint(0xf0453); iconSize: 17; iconColor: root.mauve
                        visible: Config.showUpdates && root.updateCount > 0
                        barColors: root
                        onClicked: root.showToast("Moonlit", "Updates available", root.updateCount + " updates are waiting when you have time <3")
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Rectangle { implicitWidth: 16; implicitHeight: 1; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12); Layout.alignment: Qt.AlignHCenter }

                    TrayBtn { icon: String.fromCodePoint(0xf00af); iconSize: 16; iconColor: root.btPowered ? root.mauve : root.overlay0; active: root.activePanel === "bt"; barColors: root; onClicked: root.openPanel("bt"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn { icon: (root.volMuted || root.volPct === 0) ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e); iconSize: 18; active: root.activePanel === "audio"; barColors: root; onClicked: root.openPanel("audio"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn { icon: String.fromCodePoint(0xf328); iconSize: 20; active: root.activePanel === "clip"; barColors: root; onClicked: root.openPanel("clip"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn { icon: String.fromCodePoint(0xf013); active: root.activePanel === "qs"; barColors: root; onClicked: root.openPanel("qs"); Layout.alignment: Qt.AlignHCenter }
                    TrayBtn { icon: String.fromCodePoint(0xf011); iconColor: root.maroon; barColors: root; onClicked: root.openPanel("power"); Layout.alignment: Qt.AlignHCenter }
                }
            }
        }
    }

    // ── Classic vertical layout — one solid full-height strip ────────────
    Component {
        id: classicVLayout
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)

            // hairline on the inner edge (right edge when docked left, vice-versa)
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom }
                anchors.right: Config.barPosition === "left" ? parent.right : undefined
                anchors.left:  Config.barPosition === "right" ? parent.left : undefined
                width: 1
                color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)
            }

            // TOP — logo + workspaces
            ColumnLayout {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
                spacing: 6
                TrayBtn {
                    icon: String.fromCodePoint(0xf303)
                    iconColor: root.archLogo
                    iconSize: 20; barColors: root
                    onClicked: rofiProc.running = true
                    Layout.alignment: Qt.AlignHCenter
                }
                Workspaces { vertical: true; barColors: root; Layout.alignment: Qt.AlignHCenter }
            }

            // CENTER — moon-clock (moon / HH / MM)
            Item {
                anchors.centerIn: parent
                implicitWidth: 34
                implicitHeight: vcClockCol.implicitHeight

                ColumnLayout {
                    id: vcClockCol
                    anchors.centerIn: parent
                    spacing: 1
                    Text {
                        text: String.fromCodePoint(0xf186)
                        color: root.accent
                        font { pixelSize: 13; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        id: vcClockH
                        color: root.text
                        font { pixelSize: 13; bold: true; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        id: vcClockM
                        color: root.overlay2
                        font { pixelSize: 13; bold: true; family: root.nfFont }
                        Layout.alignment: Qt.AlignHCenter
                        Timer {
                            interval: 1000; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                var now = new Date()
                                vcClockH.text = Qt.formatDateTime(now, Config.clock24h ? "HH" : "hh")
                                vcClockM.text = Qt.formatDateTime(now, "mm")
                            }
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openPanel("cal")
                }
            }

            // BOTTOM — stats + controls + power
            ColumnLayout {
                anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
                spacing: 3

                TrayBtn { icon: String.fromCodePoint(0xf4bc); iconSize: 17; active: root.activePanel === "sysmon"; barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn { icon: String.fromCodePoint(0xe266); iconSize: 15; active: root.activePanel === "sysmon"; barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn {
                    icon: root.battCharging ? String.fromCodePoint(0xf0084) : (root.battPct > 20 ? String.fromCodePoint(0xf0079) : String.fromCodePoint(0xf007a))
                    iconSize: 15
                    iconColor: root.battCharging ? root.green : (root.battPct <= 20 ? root.red : root.subtext0)
                    visible: Config.showBattery
                    barColors: root; onClicked: root.openPanel("sysmon"); Layout.alignment: Qt.AlignHCenter
                }
                TrayBtn { icon: String.fromCodePoint(0xf0928); iconSize: 15; active: root.activePanel === "net"; barColors: root; onClicked: root.openPanel("net"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn {
                    icon: String.fromCodePoint(0xf0453); iconSize: 17; iconColor: root.mauve
                    visible: Config.showUpdates && root.updateCount > 0
                    barColors: root
                    onClicked: root.showToast("Moonlit", "Updates available", root.updateCount + " updates are waiting when you have time <3")
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { implicitWidth: 18; implicitHeight: 1; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12); Layout.alignment: Qt.AlignHCenter }

                TrayBtn { icon: String.fromCodePoint(0xf00af); iconSize: 16; iconColor: root.btPowered ? root.mauve : root.overlay0; active: root.activePanel === "bt"; barColors: root; onClicked: root.openPanel("bt"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn { icon: (root.volMuted || root.volPct === 0) ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e); iconSize: 18; active: root.activePanel === "audio"; barColors: root; onClicked: root.openPanel("audio"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn { icon: String.fromCodePoint(0xf328); iconSize: 20; active: root.activePanel === "clip"; barColors: root; onClicked: root.openPanel("clip"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn { icon: String.fromCodePoint(0xf013); active: root.activePanel === "qs"; barColors: root; onClicked: root.openPanel("qs"); Layout.alignment: Qt.AlignHCenter }
                TrayBtn { icon: String.fromCodePoint(0xf011); iconColor: root.maroon; barColors: root; onClicked: root.openPanel("power"); Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    Component {
        id: islandsLayout
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
                    color: root.archLogo
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

                Rectangle { anchors.fill: parent; radius: 999; color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b,0.5) }

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
            color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)
            border.color: root.activePanel === "cal"
                        ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.65)
                        : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
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
                        onTriggered: clockTxt.text = Qt.formatDateTime(new Date(), Config.clock24h ? "hh:mm" : "h:mm AP")
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
                visible: Config.showTemp && sysStats.cpuTemp >= 75
                active: true
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: root.battCharging ? "󰂄" : (root.battPct > 20 ? "󰁹" : "󰁺")
                label: ""
                value: root.battPct + "%"
                visible: Config.showBattery
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
                visible: Config.showUpdates && root.updateCount > 0
                barColors: root
                onClicked: root.showToast(
                    "Moonlit",
                    "Updates available",
                    root.aurHelper !== ""
                        ? root.pacmanUpdateCount + " pacman and " + root.aurUpdateCount + " AUR updates are waiting when you have time <3"
                        : root.pacmanUpdateCount + " pacman updates are waiting when you have time <3"
                )
            }

            Rectangle { width: 1; height: 18; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.12); Layout.alignment: Qt.AlignVCenter }

            TrayBtn {
                icon: "󰕧"
                iconSize: 19
                iconColor: root.recordingActive ? root.red : root.overlay0
                visible: Config.showRecording && root.recordingActive
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

            Rectangle { width: 1; height: 18; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.12); Layout.alignment: Qt.AlignVCenter }

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
    }

    Component {
        id: classicLayout
        Item {
            anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)

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
                    color: root.archLogo
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

                Rectangle { anchors.fill: parent; radius: 999; color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b,0.5) }

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
                icon: "󰔏"; label: ""
                value: Math.round(sysStats.cpuTemp) + "C"
                iconSize: 15
                iconColor: root.peach
                visible: Config.showTemp && sysStats.cpuTemp >= 75
                active: true
                barColors: root
                onClicked: root.openPanel("sysmon")
            }

            BarMod {
                icon: root.battCharging ? "󰂄" : (root.battPct > 20 ? "󰁹" : "󰁺")
                label: ""
                value: root.battPct + "%"
                visible: Config.showBattery
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
                visible: Config.showUpdates && root.updateCount > 0
                barColors: root
                onClicked: root.showToast(
                    "Moonlit",
                    "Updates available",
                    root.aurHelper !== ""
                        ? root.pacmanUpdateCount + " pacman and " + root.aurUpdateCount + " AUR updates are waiting when you have time <3"
                        : root.pacmanUpdateCount + " pacman updates are waiting when you have time <3"
                )
            }

            Rectangle { width: 1; height: 18; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.12); Layout.alignment: Qt.AlignVCenter }

            TrayBtn {
                icon: "󰕧"
                iconSize: 19
                iconColor: root.recordingActive ? root.red : root.overlay0
                visible: Config.showRecording && root.recordingActive
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

            Rectangle { width: 1; height: 18; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.12); Layout.alignment: Qt.AlignVCenter }

            Tray { barColors: root; Layout.alignment: Qt.AlignVCenter }

            // Settings — ⚙ gear (U+2699)
            TrayBtn {
                icon: ""
                active: root.activePanel === "qs"
                barColors: root
                onClicked: root.openPanel("qs")
            }

            Rectangle { width: 1; height: 18; color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.12); Layout.alignment: Qt.AlignVCenter }

            // Clock
            Item {
                implicitHeight: 28
                implicitWidth: clockTxt.implicitWidth + 20
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent; radius: 999
                    color: root.activePanel === "cal"
                           ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b,0.16)
                           : (clockHov.containsMouse ? Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.07) : "transparent")
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                Text {
                    id: clockTxt
                    anchors.centerIn: parent
                    color: root.activePanel === "cal" ? root.accent : root.text
                    font { pixelSize: 13; bold: true; family: root.nfFont }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: clockTxt.text = Qt.formatDateTime(new Date(), Config.clock24h ? "hh:mm" : "h:mm AP")
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
                activeHoverColor: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b,0.16)
            }
        }
    }
        }
    }

    // ── Inline components ────────────────────────────────────────────────

    // Floating pill "island" — the fresh-aesthetic module silhouette
    component Island: Rectangle {
        implicitHeight: 34
        radius: height / 2
        color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, Config.barOpacity)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
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
                 : modHov.containsMouse ? Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.07)
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
        property color  activeHoverColor: Qt.rgba(Config.text.r, Config.text.g, Config.text.b,0.07)
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
