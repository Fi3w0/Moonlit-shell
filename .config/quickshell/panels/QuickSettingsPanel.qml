import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()
    signal showOsd(string kind, real value)
    signal openPanel(string name)

    // Quick-settings state owned by shell.qml (shared across screens)
    property bool dndOn:      false
    property bool caffeineOn: false
    property bool nightOn:    false
    signal toggleDnd()
    signal toggleCaffeine()
    signal toggleNight()

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: qsContent.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color  base:     "#1e1e2e"
    readonly property color  mantle:   "#181825"
    readonly property color  surface0: "#313244"
    readonly property color  surface1: "#45475a"
    readonly property color  surface2: "#585b70"
    readonly property color  overlay0: "#6c7086"
    readonly property color  overlay1: "#7f849c"
    readonly property color  subtext0: "#a6adc8"
    readonly property color  text:     "#cdd6f4"
    readonly property color  pink:     "#f38ba8"
    readonly property color  green:    "#a6e3a1"
    readonly property color  mauve:    "#cba6f7"
    readonly property color  crust:    "#11111b"

    // Native data
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }

    property bool air:   false

    readonly property bool btPowered: Bluetooth.defaultAdapter?.enabled ?? false

    // Uptime via shell
    property string uptime: ""
    Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/up //' | sed 's/ hours\\?/h/' | sed 's/ minutes\\?/m/'"]
        stdout: SplitParser { onRead: d => root.uptime = d.trim() }
        running: true
    }

    Rectangle {
        id: qsContent
        width: parent.width
        implicitHeight: qsCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: qsCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // ── User header ───────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 72

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0xf3/255, 0x8b/255, 0xa8/255, 0.08)
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 0

                    Rectangle {
                        width: 42; height: 42; radius: 13
                        color: Qt.rgba(0xf3/255, 0x8b/255, 0xa8/255, 0.16)

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: "#f38ba8"
                            font { pixelSize: 38; family: root.nfFont }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        Process {
                            id: userProc
                            command: ["sh", "-c", "echo $(whoami)@$(hostname)"]
                            stdout: SplitParser { onRead: d => userLabel.text = d.trim() }
                            running: true
                        }
                        Text { id: userLabel; color: root.text; font { pixelSize: 16; bold: true; family: root.nfFont } }
                        Text { text: root.uptime ? "uptime " + root.uptime : ""; color: root.overlay1; font { pixelSize: 13; family: root.nfFont } }
                    }

                    Item {
                        width: 38; height: 38

                        Rectangle { anchors.fill: parent; radius: 12; color: pwrHov.containsMouse ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16) : "transparent" }
                        Text { anchors.centerIn: parent; text: ""; color: "#eba0ac"; font { pixelSize: 22; family: root.nfFont } }
                        MouseArea { id: pwrHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openPanel("power") }
                    }
                }
            }

            // ── Body ──────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 10

                // Toggles 2x3 grid
                Grid {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    component ToggleBtn: Item {
                        id: tbn
                        property string icon:  ""
                        property string label: ""
                        property string sub:   ""
                        property bool   on:    false
                        signal toggled()

                        width: (360 - 32 - 8) / 2
                        height: 64

                        Rectangle {
                            anchors.fill: parent; radius: 16
                            color: tbn.on ? root.pink : root.surface0
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        RowLayout {
                            anchors { fill: parent; margins: 14 }
                            spacing: 12

                            Rectangle {
                                width: 38; height: 38; radius: 12
                                color: tbn.on ? Qt.rgba(0x11/255,0x11/255,0x1b/255,0.16)
                                             : Qt.rgba(0x11/255,0x11/255,0x1b/255,0.28)

                                Text {
                                    anchors.centerIn: parent
                                    text: tbn.icon
                                    color: tbn.on ? root.crust : root.text
                                    font { pixelSize: 18; family: root.nfFont }
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text {
                                    text: tbn.label
                                    color: tbn.on ? root.crust : root.text
                                    font { pixelSize: 12; bold: true; family: root.nfFont }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: tbn.sub
                                    color: tbn.on ? Qt.rgba(0x11/255,0x11/255,0x1b/255,0.7) : root.overlay1
                                    font { pixelSize: 10; family: root.nfFont }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tbn.toggled()
                        }
                    }

                    ToggleBtn {
                        icon: "󰤨"
                        label: "Wi-Fi"
                        sub: Networking.wifiEnabled ? "Enabled" : "Off"
                        on: Networking.wifiEnabled
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }

                    ToggleBtn {
                        icon: "󰂯"
                        label: "Bluetooth"
                        sub: root.btPowered ? "On" : "Off"
                        on: root.btPowered
                        onToggled: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }

                    ToggleBtn {
                        icon: "󰕚"
                        label: "Do Not Disturb"
                        sub: root.dndOn ? "Silenced" : "Off"
                        on: root.dndOn
                        onToggled: root.toggleDnd()
                    }

                    ToggleBtn {
                        icon: "󰖔"
                        label: "Night Light"
                        sub: root.nightOn ? "Warm" : "Off"
                        on: root.nightOn
                        onToggled: root.toggleNight()
                    }

                    ToggleBtn {
                        icon: "󰅶"
                        label: "Caffeine"
                        sub: root.caffeineOn ? "Awake" : "Off"
                        on: root.caffeineOn
                        onToggled: root.toggleCaffeine()
                    }

                    ToggleBtn {
                        icon: "󰀝"
                        label: "Airplane"
                        sub: root.air ? "On" : "Off"
                        on: root.air
                        onToggled: {
                            root.air = !root.air
                            Qt.createQmlObject(
                                'import Quickshell.Io; Process { command: ["sh","-c","' +
                                (root.air ? "rfkill block all" : "rfkill unblock all") +
                                '"]; running: true }', root)
                        }
                    }
                }

                // Volume slider
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 16; color: root.surface0

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 13

                        Text {
                            text: "󰕾"
                            color: root.subtext0
                            font { pixelSize: 20; family: root.nfFont }
                        }

                        Item {
                            Layout.fillWidth: true; height: 8

                            Rectangle { anchors.fill: parent; radius: 99; color: root.surface2 }
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSink?.audio?.volume ?? 0))
                                height: 8; radius: 99; color: root.pink
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                            Rectangle {
                                x: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSink?.audio?.volume ?? 0)) - 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8
                                color: root.text
                            }

                            MouseArea {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 26
                                cursorShape: Qt.PointingHandCursor
                                function setVol(mx) {
                                    var v = Math.max(0, Math.min(1, mx / width))
                                    if (Pipewire.defaultAudioSink?.audio) {
                                        Pipewire.defaultAudioSink.audio.volume = v
                                        root.showOsd("volume", Math.round(v * 100))
                                    }
                                }
                                onPressed: mouse => setVol(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setVol(mouse.x) }
                            }
                        }

                        Text {
                            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                            color: root.subtext0
                            font { pixelSize: 12; bold: true; family: root.nfFont }
                            width: 36; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Brightness slider
                Rectangle {
                    id: brightCard
                    Layout.fillWidth: true; height: 52; radius: 16; color: root.surface0
                    visible: brightCard.hasBacklight

                    property int  brightness: 50
                    property bool hasBacklight: false
                    property bool dragging: false

                    Process {
                        id: brightnessProc
                        command: ["brightnessctl", "-m"]
                        running: true
                        stdout: SplitParser {
                            onRead: line => {
                                var f = line.trim().split(",")
                                if (f.length >= 4 && f[1] === "backlight") {
                                    brightCard.brightness   = parseInt(f[3]) || 0
                                    brightCard.hasBacklight = true
                                }
                            }
                        }
                    }

                    // Keep the slider in sync with brightness changed elsewhere
                    // (keys / OSD / CLI). Polls only while the panel is open and
                    // pauses during a drag so it doesn't fight the user.
                    Timer {
                        interval: 350
                        repeat: true
                        triggeredOnStart: true
                        running: root.visible && !brightCard.dragging
                        onTriggered: brightnessProc.running = true
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 13

                        Text {
                            text: "󰃞"
                            color: root.subtext0
                            font { pixelSize: 20; family: root.nfFont }
                        }

                        Item {
                            Layout.fillWidth: true; height: 8

                            Rectangle { anchors.fill: parent; radius: 99; color: root.surface2 }
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, brightCard.brightness / 100))
                                height: 8; radius: 99; color: "#f9e2af"
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                            Rectangle {
                                x: parent.width * Math.max(0, Math.min(1, brightCard.brightness / 100)) - 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8; color: root.text
                            }

                            MouseArea {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 26
                                cursorShape: Qt.PointingHandCursor
                                function setBright(mx, commit) {
                                    var pct = Math.max(1, Math.min(100, Math.round(mx / width * 100)))
                                    brightCard.brightness = pct
                                    root.showOsd("brightness", pct)
                                    if (commit)
                                        Qt.createQmlObject(
                                            'import Quickshell.Io; Process { command: ["brightnessctl","s","' + pct + '%"]; running: true }',
                                            root)
                                }
                                onPressed: mouse => { brightCard.dragging = true; setBright(mouse.x, true) }
                                onPositionChanged: mouse => { if (pressed) setBright(mouse.x, false) }
                                onReleased: mouse => { setBright(mouse.x, true); brightCard.dragging = false }
                            }
                        }

                        Text {
                            text: brightCard.brightness + "%"
                            color: root.subtext0
                            font { pixelSize: 12; bold: true; family: root.nfFont }
                            width: 36; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                // Footer chips
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            { label: "Audio",     icon: "󰘮", panel: "audio"  },
                            { label: "Clipboard", icon: "󰅬",    panel: "clip"   },
                            { label: "System",    icon: "",     panel: "sysmon" },
                        ]
                        delegate: Item {
                            id: chipItem
                            required property var modelData
                            Layout.fillWidth: true
                            height: 38

                            Rectangle {
                                anchors.fill: parent; radius: 999
                                color: chipHov.containsMouse ? root.surface1 : root.surface0
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 7
                                Text { text: chipItem.modelData.icon; color: root.subtext0; verticalAlignment: Text.AlignVCenter; font { pixelSize: 14; family: root.nfFont } }
                                Text { text: chipItem.modelData.label; color: root.subtext0; verticalAlignment: Text.AlignVCenter; font { pixelSize: 12; family: root.nfFont } }
                            }
                            MouseArea {
                                id: chipHov
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.openPanel(chipItem.modelData.panel)
                            }
                        }
                    }
                }
            }
        }
    }
}
