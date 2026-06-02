import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: Math.min(clipContent.implicitHeight + 10, 500)
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color subtext0: "#a6adc8"
    readonly property color text:     "#cdd6f4"
    readonly property color pink:     "#f38ba8"
    readonly property color green:    "#a6e3a1"

    ListModel { id: clipModel }
    property int copiedIdx: -1

    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -20"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() !== "") {
                    // cliphist format: "ID\tCONTENT"
                    var tab = data.indexOf("\t")
                    var id = tab >= 0 ? data.substring(0, tab) : ""
                    var txt = tab >= 0 ? data.substring(tab + 1) : data
                    clipModel.append({ clipId: id, text: txt.trim().substring(0, 120) })
                }
            }
        }
    }

    onVisibleChanged: if (visible) {
        clipModel.clear()
        copiedIdx = -1
        clipProc.running = true
    }

    Rectangle {
        id: clipContent
        width: parent.width
        implicitHeight: Math.min(clipCol.implicitHeight + 10, 490)
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: clipCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "CLIPBOARD"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Clear"
                    color: root.pink
                    font { pixelSize: 11; family: root.nfFont }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Qt.createQmlObject('import Quickshell.Io; Process { command: ["sh","-c","cliphist wipe"]; running: true }', root)
                            clipModel.clear()
                        }
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                implicitHeight: 80
                visible: clipModel.count === 0 && !clipProc.running

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰅬"; color: root.overlay0; font { pixelSize: 28; family: root.nfFont } opacity: 0.6 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Clipboard is empty"; color: root.overlay0; font { pixelSize: 12; family: root.nfFont } }
                }
            }

            // Clip list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                spacing: 2
                visible: clipModel.count > 0

                Repeater {
                    model: clipModel
                    delegate: Item {
                        required property var model
                        required property int index
                        Layout.fillWidth: true
                        height: 44

                        Rectangle {
                            anchors.fill: parent; radius: 11
                            color: clipHov.containsMouse ? root.surface0 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 11

                            Text {
                                text: "󰅬"
                                color: root.overlay1
                                font { pixelSize: 15; family: root.nfFont }
                            }

                            Text {
                                text: model.text
                                color: root.text
                                font { pixelSize: 12; family: root.nfFont }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.copiedIdx === parent.parent.parent.index ? "󰄬" : "󰆎"
                                color: root.copiedIdx === parent.parent.parent.index ? root.green : root.overlay0
                                font { pixelSize: 15; family: root.nfFont }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: clipHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.copiedIdx = parent.index
                                var id = parent.model.clipId
                                Qt.createQmlObject(
                                    'import Quickshell.Io; Process { command: ["sh","-c","cliphist decode ' + id + ' | wl-copy"]; running: true }',
                                    root)
                                copiedTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer { id: copiedTimer; interval: 900; onTriggered: root.copiedIdx = -1 }
}
