import Quickshell
import Quickshell.Widgets
import QtQuick

// A catppuccin-styled popup that renders a tray item's DBus menu.
// Submenus drill down in-place (with a Back row) — no recursive instantiation.
PopupWindow {
    id: pop
    required property var handle      // root QsMenuHandle (item.menu)
    required property var barColors
    signal closeAll()

    // navigation stack of submenu handles; root = pop.handle
    property var stack: []
    property var current: handle
    function enter(h) { stack = stack.concat([h]); current = h }
    function back()    { stack = stack.slice(0, -1); current = stack.length ? stack[stack.length - 1] : pop.handle }
    function reset()   { stack = []; current = pop.handle }
    onVisibleChanged: if (!visible) reset()

    QsMenuOpener { id: opener; menu: pop.current }

    implicitWidth: 248
    implicitHeight: bg.implicitHeight
    color: "transparent"

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 12
        radius: 14
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.97)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.10)

        Column {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
            spacing: 1

            // Back row (only inside a submenu)
            Rectangle {
                visible: pop.stack.length > 0
                width: col.width; height: 30; radius: 8
                color: backMa.containsMouse ? Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.18) : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; spacing: 9
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""; color: pop.barColors.mauve
                        font.family: pop.barColors.nfFont; font.pixelSize: 13
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"; color: pop.barColors.subtext0
                        font.family: pop.barColors.nfFont; font.pixelSize: 12
                    }
                }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: pop.back() }
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entryItem
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 9 : 32

                    Rectangle {
                        visible: entryItem.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 14; height: 1
                        color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.10)
                    }

                    Rectangle {
                        visible: !entryItem.modelData.isSeparator
                        anchors.fill: parent
                        radius: 8
                        color: ma.containsMouse && entryItem.modelData.enabled
                               ? Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.18) : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Item {
                                width: 16; height: parent.height
                                Text {
                                    anchors.centerIn: parent
                                    visible: entryItem.modelData.buttonType !== 0
                                    text: entryItem.modelData.checkState !== 0 ? "󰄬" : "󰄱"
                                    color: pop.barColors.green
                                    font.family: pop.barColors.nfFont
                                    font.pixelSize: 13
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: entryItem.modelData.buttonType === 0 && entryItem.modelData.icon !== ""
                                    implicitSize: 16
                                    source: entryItem.modelData.icon
                                }
                            }

                            Text {
                                width: parent.width - 16 - 9 - (entryItem.modelData.hasChildren ? 18 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                text: (entryItem.modelData.text || "").replace(/_(.)/g, "$1")
                                color: entryItem.modelData.enabled ? pop.barColors.text : pop.barColors.overlay0
                                font.family: pop.barColors.nfFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: entryItem.modelData.hasChildren
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: pop.barColors.subtext0
                                font.family: pop.barColors.nfFont
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryItem.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entryItem.modelData.hasChildren) {
                                    pop.enter(entryItem.modelData)
                                } else {
                                    entryItem.modelData.triggered()
                                    pop.closeAll()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
