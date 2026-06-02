import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 322
    implicitHeight: btContent.implicitHeight + 10
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
    readonly property color green:    "#a6e3a1"

    // ── BT state via native Bluetooth service ─────────────────────────────
    readonly property bool btOn: Bluetooth.defaultAdapter?.enabled ?? false
    property bool   scanning: false
    ListModel { id: devModel }

    // Poll paired + connected devices every 3s
    property var devBuffer: []
    Process {
        id: devProc
        command: ["sh", "-c",
            "bluetoothctl devices Paired 2>/dev/null | sed 's/Device //' | while read addr name; do " +
            "  conn=$(bluetoothctl info \"$addr\" 2>/dev/null | grep -c 'Connected: yes'); " +
            "  echo \"$addr|$conn|$name\"; " +
            "done"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: d => {
                if (d.trim() === "") return
                var p = d.trim().split("|")
                if (p.length >= 3) {
                    root.devBuffer.push({
                        address:   p[0].trim(),
                        connected: p[1].trim() === "1",
                        name:      p.slice(2).join("|").trim()
                    })
                }
            }
        }
        onRunningChanged: {
            if (!running && root.devBuffer.length >= 0) {
                devModel.clear()
                for (var i = 0; i < root.devBuffer.length; i++)
                    devModel.append(root.devBuffer[i])
                root.devBuffer = []
            }
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (root.visible && root.btOn) { root.devBuffer = []; devProc.running = true }
    }

    // Scan process
    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onRunningChanged: if (!running) root.scanning = false
    }

    onVisibleChanged: {
        if (visible && btOn) {
            devBuffer = []; devProc.running = true
            scanning = true; scanProc.running = true
        } else {
            scanProc.running = false; scanning = false
        }
    }


    Rectangle {
        id: btContent
        width: parent.width
        implicitHeight: btCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: btCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "BLUETOOTH"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }

                Text {
                    text: " scanning…"
                    color: root.blue
                    font { pixelSize: 10; family: root.nfFont }
                    visible: root.scanning
                }

                Item { Layout.fillWidth: true }

                // Scan button
                Rectangle {
                    visible: root.btOn
                    width: 28; height: 24; radius: 8
                    color: scanHov.containsMouse
                           ? Qt.rgba(0x89/255,0xb4/255,0xfa/255,0.16) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: root.scanning ? root.pink : root.blue
                        font { pixelSize: 15; family: root.nfFont }
                        RotationAnimation on rotation {
                            running: root.scanning
                            from: 0; to: 360; duration: 1200
                            loops: Animation.Infinite
                        }
                    }
                    MouseArea {
                        id: scanHov
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!root.scanning) {
                                root.scanning = true
                                scanProc.running = false
                                scanProc.running = true
                            }
                        }
                    }
                }

                // Power toggle
                Rectangle {
                    width: 42; height: 24; radius: 999
                    color: root.btOn ? root.pink : root.surface2
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        x: root.btOn ? 21 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18; radius: 9
                        color: root.btOn ? "#11111b" : root.text
                        Behavior on x { NumberAnimation { duration: 160 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }
                }
            }

            // Off state
            Item {
                Layout.fillWidth: true
                implicitHeight: 80
                visible: !root.btOn

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰂲"; color: root.overlay0; opacity: 0.6; font { pixelSize: 28; family: root.nfFont } }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Bluetooth is off"; color: root.overlay0; font { pixelSize: 12; family: root.nfFont } }
                }
            }

            // Device list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 8
                spacing: 2
                visible: root.btOn

                Repeater {
                    model: devModel
                    delegate: Item {
                        id: devRow
                        required property var model
                        Layout.fillWidth: true; height: 52

                        Rectangle {
                            anchors.fill: parent; radius: 11
                            color: devRow.model.connected
                                   ? Qt.rgba(0x89/255,0xb4/255,0xfa/255,0.10)
                                   : devHov.containsMouse ? root.surface0 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                            spacing: 10

                            Text {
                                text: {
                                    var n = (devRow.model.name || "").toLowerCase()
                                    if (n.includes("headphone") || n.includes("buds") || n.includes("earphone")) return "󰋋"
                                    if (n.includes("speaker")) return "󰓃"
                                    if (n.includes("mouse"))    return "󰍽"
                                    if (n.includes("keyboard")) return "󰌌"
                                    if (n.includes("phone"))    return "󰏲"
                                    return "󰂯"
                                }
                                color: devRow.model.connected ? root.blue : root.subtext0
                                font { pixelSize: 18; family: root.nfFont }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text {
                                    text: devRow.model.name || devRow.model.address
                                    color: root.text; font { pixelSize: 12; family: root.nfFont }
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: devRow.model.connected ? "Connected" : "Paired"
                                    color: devRow.model.connected ? root.blue : root.overlay0
                                    font { pixelSize: 10; family: root.nfFont }
                                }
                            }

                            Rectangle {
                                implicitWidth: actTxt.implicitWidth + 18; height: 24; radius: 999
                                color: devRow.model.connected
                                       ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
                                       : Qt.rgba(0x89/255,0xb4/255,0xfa/255,0.14)

                                Text {
                                    id: actTxt; anchors.centerIn: parent
                                    text: devRow.model.connected ? "Disconnect" : "Connect"
                                    color: devRow.model.connected ? root.pink : root.blue
                                    font { pixelSize: 10; bold: true; family: root.nfFont }
                                }

                                MouseArea {
                                    id: devHov
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var addr = devRow.model.address
                                        var cmd = devRow.model.connected ? "disconnect" : "connect"
                                        Qt.createQmlObject(
                                            'import Quickshell.Io; Process { command: ["bluetoothctl","' + cmd + '","' + addr + '"]; running: true }',
                                            root)
                                        Qt.callLater(() => { root.devBuffer = []; devProc.running = true })
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10; Layout.bottomMargin: 4
                    text: devModel.count === 0
                          ? (root.scanning ? "Searching…" : "No paired devices")
                          : ""
                    visible: text !== ""
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                }
            }
        }
    }
}
