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

    function dismissAt(i) {
        if (i >= 0 && i < toastModel.count)
            toastModel.setProperty(i, "closing", true)
    }

    Connections {
        target: root.relay
        function onNotify(app, title, body) {
            var id = Date.now()
            toastModel.append({ tid: id, app: app, title: title, body: body, closing: false })
            Qt.createQmlObject(
                'import QtQuick; Timer { interval: 4200; running: true; onTriggered: { for(var i=0;i<toastModel.count;i++){if(toastModel.get(i).tid===' + id + '){toastModel.setProperty(i,"closing",true);break;}} destroy() } }',
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
                property bool entered: false

                Layout.fillWidth: true
                implicitHeight: toastRow.implicitHeight + 24
                radius: 16
                color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.98)
                border.width: 1
                border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
                opacity: model.closing ? 0 : (entered ? 1 : 0)
                x: model.closing ? width + 28 : 0

                Component.onCompleted: entered = true
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: model.closing ? 180 : 260; easing.type: model.closing ? Easing.InCubic : Easing.OutCubic } }
                Timer {
                    interval: 240
                    running: model.closing
                    onTriggered: if (index >= 0 && index < toastModel.count) toastModel.remove(index)
                }

                RowLayout {
                    id: toastRow
                    anchors { fill: parent; margins: 12 }
                    spacing: 11

                    Rectangle {
                        width: 36; height: 36; radius: 11
                        color: Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.18)
                        Layout.alignment: Qt.AlignTop

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: "#cba6f7"
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
                        Text {
                            text: model.title
                            color: "#cdd6f4"
                            font { pixelSize: 13; bold: true; family: root.nfFont }
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: model.body
                            color: "#a6adc8"
                            font { pixelSize: 12; family: root.nfFont }
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "󰅖"
                        color: "#6c7086"
                        font { pixelSize: 14; family: root.nfFont }
                        Layout.alignment: Qt.AlignTop

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissAt(parent.parent.parent.index)
                        }
                    }
                }
            }
        }
    }
}
