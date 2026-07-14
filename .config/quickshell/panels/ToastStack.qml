import Quickshell
import QtQuick
import QtQuick.Layouts
import "../services"

PanelWindow {
    id: root
    required property var relay

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 50 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
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
                color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
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
                        color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                        Layout.alignment: Qt.AlignTop

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: Config.accent
                            font { pixelSize: 17; family: root.nfFont }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        RowLayout {
                            Text { text: model.app; color: Config.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } }
                            Item { Layout.fillWidth: true }
                            Text { text: "now"; color: Config.overlay0; font { pixelSize: 10; family: root.nfFont } }
                        }
                        Text {
                            text: model.title
                            color: Config.text
                            font { pixelSize: 13; bold: true; family: root.nfFont }
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: model.body
                            color: Config.subtext0
                            font { pixelSize: 12; family: root.nfFont }
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: "󰅖"
                        color: Config.overlay0
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
