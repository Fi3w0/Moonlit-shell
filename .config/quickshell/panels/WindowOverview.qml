import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../services"

// Mission-Control-style window switcher: a dimmed full-screen overlay with a
// live-thumbnail grid of every open window (across all workspaces). Click a
// thumbnail (or arrow-key + Enter) to focus it; Escape or click-empty to
// close without switching.
PanelWindow {
    id: root
    signal close()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) {
        keyHandler.forceActiveFocus()
        selectedIndex = Math.max(0, indexOfActive())
    }

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    property int selectedIndex: 0

    function indexOfActive() {
        for (var i = 0; i < Hyprland.toplevels.values.length; i++) {
            if (Hyprland.toplevels.values[i].activated) return i
        }
        return 0
    }

    function activate(toplevel) {
        if (!toplevel) return
        toplevel.wayland.activate()
        root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.75)

        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true; easing.type: Easing.OutCubic }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Hyprland.toplevels.values.length > 0 ? "Windows" : "No windows open"
                color: Config.text
                font { pixelSize: 16; bold: true; family: root.nfFont }
            }

            GridView {
                id: grid
                readonly property int columns: Math.max(1, Math.min(4, Hyprland.toplevels.values.length))
                Layout.preferredWidth: columns * cellWidth
                Layout.preferredHeight: Math.min(
                    Math.ceil(Hyprland.toplevels.values.length / columns) * cellHeight,
                    root.height - 160)
                Layout.maximumWidth: root.width - 80

                cellWidth: 260
                cellHeight: 190
                interactive: false
                model: Hyprland.toplevels

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    property bool hov: false
                    readonly property bool selected: root.selectedIndex === index

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 10
                        radius: 14
                        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.96)
                        border.width: cell.selected || cell.modelData.activated ? 2 : 1
                        border.color: (cell.hov || cell.selected || cell.modelData.activated)
                            ? Config.accent
                            : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
                        y: cell.hov || cell.selected ? -4 : 0
                        Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        clip: true

                        ScreencopyView {
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.bottomMargin: 28
                            captureSource: cell.modelData.wayland
                            live: true
                        }

                        // Workspace badge
                        Rectangle {
                            visible: cell.modelData.workspace !== null
                            anchors { top: parent.top; left: parent.left; margins: 8 }
                            width: wsLabel.implicitWidth + 10; height: 18; radius: 6
                            color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.85)
                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                text: cell.modelData.workspace ? cell.modelData.workspace.id : ""
                                color: Config.subtext0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 26
                            color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.55)
                            Text {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                verticalAlignment: Text.AlignVCenter
                                text: cell.modelData.title
                                color: Config.text
                                font { pixelSize: 11; family: root.nfFont }
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { cell.hov = true; root.selectedIndex = cell.index }
                        onExited: cell.hov = false
                        onClicked: root.activate(cell.modelData)
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "esc to cancel  ·  click or enter to switch"
                color: Config.subtext0
                font { pixelSize: 11; family: root.nfFont }
            }
        }
    }

    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            var cols = grid.columns
            var count = Hyprland.toplevels.values.length
            switch (ev.key) {
                case Qt.Key_Escape:
                    root.close()
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activate(Hyprland.toplevels.values[root.selectedIndex])
                    break
                case Qt.Key_Right:
                    if (count > 0) root.selectedIndex = (root.selectedIndex + 1) % count
                    break
                case Qt.Key_Left:
                    if (count > 0) root.selectedIndex = (root.selectedIndex - 1 + count) % count
                    break
                case Qt.Key_Down:
                    if (count > 0) root.selectedIndex = Math.min(root.selectedIndex + cols, count - 1)
                    break
                case Qt.Key_Up:
                    if (count > 0) root.selectedIndex = Math.max(root.selectedIndex - cols, 0)
                    break
                case Qt.Key_Tab:
                    if (count > 0) root.selectedIndex = (root.selectedIndex + 1) % count
                    break
            }
        }
    }
}
