import Quickshell
import QtQuick
import "../services"

PanelWindow {
    id: root
    required property string kind
    required property real   value

    anchors { bottom: true; left: true; right: true }
    margins.bottom: 70
    exclusiveZone: 0
    implicitHeight: 60
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color  accent:   Config.accent
    readonly property color  yellow: "#f9e2af"

    Item {
        anchors.centerIn: parent
        width: 300; height: 52

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: Qt.rgba(Config.mantle.r, Config.mantle.g, Config.mantle.b, 0.94)
            border.width: 1
            border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)

            Row {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.kind === "volume"
                          ? (root.value === 0 ? "󰖁" : "󰕾")
                          : "󰃞"
                    color: root.kind === "volume" ? root.accent : root.yellow
                    font { pixelSize: 22; family: root.nfFont }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 22 - 14 - 40; height: 8
                    radius: 999
                    color: Config.surface2

                    Rectangle {
                        width: parent.width * (root.value / 100)
                        height: 8; radius: 999
                        color: root.kind === "volume" ? root.accent : root.yellow
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.value
                    color: Config.text
                    font { pixelSize: 14; bold: true; family: root.nfFont }
                    width: 34; horizontalAlignment: Text.AlignRight
                }
            }
        }

        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }
    }
}
