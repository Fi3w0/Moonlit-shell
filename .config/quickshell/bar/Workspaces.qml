import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../services"

// Dot workspaces — pill for active, dot for occupied/empty.
// Lays out horizontally, or vertically when `vertical` is set (side bar).
Item {
    id: root
    required property var barColors
    property bool vertical: false

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int maxId: Math.max(5, focusedId)

    function isOccupied(id) {
        for (var i = 0; i < Hyprland.workspaces.length; i++) {
            if ((Hyprland.workspaces[i]?.id ?? 0) === id) return true
        }
        return false
    }

    implicitWidth:  vertical ? 28 : pill.implicitWidth
    implicitHeight: vertical ? pill.implicitHeight : 28

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth:  root.vertical ? 28 : wsGrid.implicitWidth + 18
        implicitHeight: root.vertical ? wsGrid.implicitHeight + 18 : 28
        width: implicitWidth
        height: implicitHeight
        radius: 999
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.5)

        Grid {
            id: wsGrid
            anchors.centerIn: parent
            rows:    root.vertical ? root.maxId : 1
            columns: root.vertical ? 1 : root.maxId
            rowSpacing: 5
            columnSpacing: 5

            Repeater {
                model: root.maxId
                delegate: Item {
                    required property int index
                    readonly property int wsId:     index + 1
                    readonly property bool active:   wsId === root.focusedId
                    readonly property bool occupied: root.isOccupied(wsId)

                    implicitWidth:  root.vertical ? 28 : (active ? 26 : 10)
                    implicitHeight: root.vertical ? (active ? 26 : 10) : 28

                    Behavior on implicitWidth  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width:  root.vertical ? 9 : (parent.active ? 26 : 9)
                        height: root.vertical ? (parent.active ? 26 : 9) : 9
                        radius: 999
                        color:  parent.active   ? root.barColors.accent
                              : parent.occupied ? root.barColors.overlay2
                              : root.barColors.surface2
                        opacity: parent.active ? 1 : parent.occupied ? 1 : 0.45

                        Behavior on width   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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
