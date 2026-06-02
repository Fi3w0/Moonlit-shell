import Quickshell
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    required property var relay

    anchors { top: true; right: true }
    margins.top: 50
    exclusiveZone: 0
    implicitWidth: 340
    implicitHeight: Math.max(toastCol.implicitHeight + 8, 1)
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    ListModel { id: toastModel }

    Connections {
        target: root.relay
        function onNotify(app, title, body) {
            var id = Date.now()
            toastModel.append({ tid: id, app: app, title: title, body: body })
            Qt.createQmlObject(
                'import QtQuick; Timer { interval: 4200; running: true; onTriggered: { for(var i=0;i<toastModel.count;i++){if(toastModel.get(i).tid===' + id + '){toastModel.remove(i);break;}} destroy() } }',
                root)
        }
    }

    ColumnLayout {
        id: toastCol
        width: parent.width
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 4 }
        spacing: 8

        Repeater {
            model: toastModel
            delegate: Rectangle {
                required property var model
                required property int index

                Layout.fillWidth: true
                implicitHeight: toastRow.implicitHeight + 24
                radius: 16
                color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.98)
                border.width: 1
                border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)

                NumberAnimation on opacity { from: 0; to: 1; duration: 260; running: true; easing.type: Easing.OutCubic }

                RowLayout {
                    id: toastRow
                    anchors { fill: parent; margins: 12 }
                    spacing: 11

                    Rectangle {
                        width: 36; height: 36; radius: 11
                        color: Qt.rgba(0xf3/255, 0x8b/255, 0xa8/255, 0.18)
                        Layout.alignment: Qt.AlignTop

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: "#f38ba8"
                            font { pixelSize: 17; family: root.nfFont }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        RowLayout {
                            Text { text: model.app; color: "#a6adc8"; font { pixelSize: 10; bold: true; family: root.nfFont } }
                            Item { Layout.fillWidth: true }
                            Text { text: "now"; color: "#6c7086"; font { pixelSize: 10; family: root.nfFont } }
                        }
                        Text { text: model.title; color: "#cdd6f4"; font { pixelSize: 13; bold: true; family: root.nfFont } Layout.fillWidth: true }
                        Text { text: model.body; color: "#a6adc8"; font { pixelSize: 12; family: root.nfFont } elide: Text.ElideRight; Layout.fillWidth: true }
                    }

                    Text {
                        text: "󰅖"
                        color: "#6c7086"
                        font { pixelSize: 14; family: root.nfFont }
                        Layout.alignment: Qt.AlignTop

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toastModel.remove(parent.parent.parent.index)
                        }
                    }
                }
            }
        }
    }
}
