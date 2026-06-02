import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: root
    signal close()

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 322
    implicitHeight: wifiContent.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color subtext0: "#a6adc8"
    readonly property color text:     "#cdd6f4"
    readonly property color pink:     "#f38ba8"
    readonly property color crust:    "#11111b"

    // ── State ─────────────────────────────────────────────────────────────
    property string connectSsid:    ""
    property bool   showPassDialog: false
    property string connectStatus:  ""

    ListModel { id: netModel }

    Process {
        id: netScanProc
        command: ["sh", "-c", "nmcli -t -f SSID,ACTIVE,SIGNAL,SECURITY dev wifi list 2>/dev/null | head -20"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "" || data.indexOf(":") < 0) return
                // nmcli -t uses : as separator; SSID may contain colons — split on first 4 only
                var idx = [0, 0, 0, 0]
                var parts = []
                var rest = data
                for (var i = 0; i < 4; i++) {
                    var p = rest.indexOf(":")
                    if (p < 0) { parts.push(rest); break }
                    parts.push(rest.substring(0, p))
                    rest = rest.substring(p + 1)
                }
                if (parts.length < 3) return
                var ssid = parts[0].trim()
                if (ssid === "" || ssid === "--") return
                // skip duplicates
                for (var j = 0; j < netModel.count; j++) {
                    if (netModel.get(j).ssid === ssid) return
                }
                netModel.append({
                    ssid:    ssid,
                    active:  parts[1] === "yes",
                    signal:  parseInt(parts[2]) || 0,
                    secured: parts.length > 3 && parts[3].trim() !== "" && parts[3].trim() !== "--"
                })
            }
        }
        onRunningChanged: if (!running) root.connectStatus = ""
    }

    Process {
        id: connectProc
        property string lastCmd: ""
        stdout: SplitParser { onRead: d => root.connectStatus = d.trim() }
        stderr: SplitParser { onRead: d => root.connectStatus = d.trim() }
        onRunningChanged: {
            if (!running) {
                netModel.clear(); netScanProc.running = true
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            showPassDialog = false; connectSsid = ""; connectStatus = ""
            netModel.clear(); netScanProc.running = true
        }
    }

    Rectangle {
        id: wifiContent
        width: parent.width
        implicitHeight: wifiCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: wifiCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "WI-FI"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 42; height: 24; radius: 999
                    color: Networking.wifiEnabled ? root.pink : root.surface2
                    Behavior on color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        x: Networking.wifiEnabled ? 21 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18; radius: 9
                        color: Networking.wifiEnabled ? "#11111b" : root.text
                        Behavior on x { NumberAnimation { duration: 160 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            // ── Password dialog ──────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                spacing: 8
                visible: root.showPassDialog

                Text {
                    text: "Connect to: " + root.connectSsid
                    color: root.text
                    font { pixelSize: 12; bold: true; family: root.nfFont }
                    Layout.fillWidth: true; elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true; height: 42; radius: 12
                    color: root.surface0
                    border.width: passInput.activeFocus ? 1 : 0
                    border.color: root.pink

                    TextInput {
                        id: passInput
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 11; bottomMargin: 11 }
                        color: root.text
                        font { pixelSize: 13; family: root.nfFont }
                        echoMode: TextInput.Password
                        clip: true
                        Keys.onReturnPressed: doConnect()
                        Keys.onEscapePressed: { root.showPassDialog = false; root.connectSsid = "" }
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        text: "Password"
                        color: root.overlay0
                        font { pixelSize: 13; family: root.nfFont }
                        visible: passInput.text === "" && !passInput.activeFocus
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: cancelHov.containsMouse ? root.surface1 : root.surface0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "Cancel"; color: root.subtext0; font { pixelSize: 12; family: root.nfFont } }
                        MouseArea { id: cancelHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.showPassDialog = false; root.connectSsid = ""; passInput.text = "" }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: connHov.containsMouse ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.24) : Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.16)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "Connect"; color: root.pink; font { pixelSize: 12; bold: true; family: root.nfFont } }
                        MouseArea { id: connHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: doConnect()
                        }
                    }
                }

                Text {
                    text: root.connectStatus
                    color: root.overlay0
                    font { pixelSize: 10; family: root.nfFont }
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    visible: root.connectStatus !== ""
                }
            }

            // ── WiFi off state ───────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 80
                visible: !Networking.wifiEnabled && !root.showPassDialog

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰤭"; color: root.overlay0; opacity: 0.6; font { pixelSize: 28; family: root.nfFont } }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Wi-Fi is off"; color: root.overlay0; font { pixelSize: 12; family: root.nfFont } }
                }
            }

            // ── Network list ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                spacing: 2
                visible: Networking.wifiEnabled && !root.showPassDialog

                Repeater {
                    model: netModel
                    delegate: Item {
                        id: netRow
                        required property var model
                        required property int index
                        Layout.fillWidth: true
                        height: 48

                        Rectangle {
                            anchors.fill: parent; radius: 11
                            color: model.active ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.10)
                                 : rowHov.containsMouse ? root.surface0 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 11

                            Text {
                                text: "󰤨"
                                color: model.active ? root.pink : root.subtext0
                                font { pixelSize: 18; family: root.nfFont }
                            }

                            Text {
                                text: model.ssid || "(hidden)"
                                color: root.text
                                font { pixelSize: 13; family: root.nfFont }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                visible: model.active
                                implicitWidth: badgeTxt.implicitWidth + 14; height: 20; radius: 999
                                color: Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.18)
                                Text { id: badgeTxt; anchors.centerIn: parent; text: "connected"; color: root.pink; font { pixelSize: 9; bold: true; family: root.nfFont } }
                            }

                            Text {
                                text: ""
                                color: root.overlay0
                                font { pixelSize: 13; family: root.nfFont }
                                visible: model.secured && !model.active
                            }

                            Row {
                                spacing: 2
                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        required property int index
                                        width: 3; radius: 2
                                        height: [5, 8, 11, 14][index]
                                        anchors.bottom: parent ? parent.bottom : undefined
                                        color: (index + 1) <= Math.ceil(netRow.model.signal / 25)
                                             ? (netRow.model.active ? root.pink : root.subtext0)
                                             : root.surface2
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (netRow.model.active) return
                                var ssid = netRow.model.ssid
                                if (netRow.model.secured) {
                                    root.connectSsid = ssid
                                    root.showPassDialog = true
                                    passInput.text = ""
                                    passInput.forceActiveFocus()
                                } else {
                                    // Open/unsecured — connect directly
                                    root.connectStatus = "Connecting…"
                                    connectProc.command = ["nmcli", "device", "wifi", "connect", ssid]
                                    connectProc.running = true
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: netScanProc.running ? "Scanning…" : (netModel.count === 0 ? "No networks found" : "")
                    visible: text !== ""
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                    Layout.topMargin: 8
                }
            }
        }
    }

    function doConnect() {
        if (connectSsid === "") return
        connectStatus = "Connecting…"
        connectProc.command = ["nmcli", "device", "wifi", "connect", connectSsid, "password", passInput.text]
        connectProc.running = true
        showPassDialog = false
        passInput.text = ""
    }
}
