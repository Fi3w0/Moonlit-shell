import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Horizontal dot workspaces — pill for active, dot for occupied/empty
Item {
    id: root
    required property var barColors

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int maxId: Math.max(5, focusedId)

    function isOccupied(id) {
        for (var i = 0; i < Hyprland.workspaces.length; i++) {
            if ((Hyprland.workspaces[i]?.id ?? 0) === id) return true
        }
        return false
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: 28

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: wsRow.implicitWidth + 18
        height: 28
        radius: 999
        color: Qt.rgba(0x11/255, 0x11/255, 0x1b/255, 0.5)

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 5

            Repeater {
                model: root.maxId
                delegate: Item {
                    required property int index
                    readonly property int wsId:     index + 1
                    readonly property bool active:   wsId === root.focusedId
                    readonly property bool occupied: root.isOccupied(wsId)

                    implicitHeight: 28
                    implicitWidth: active ? 26 : 10

                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width:  parent.active ? 26 : 9
                        height: 9
                        radius: 999
                        color:  parent.active   ? root.barColors.pink
                              : parent.occupied ? root.barColors.overlay2
                              : root.barColors.surface2
                        opacity: parent.active ? 1 : parent.occupied ? 1 : 0.45

                        Behavior on width   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color   { ColorAnimation  { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                    }
                }
            }
        }
    }
}
