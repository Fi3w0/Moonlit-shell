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
//
// Multi-monitor: this panel is instantiated per-screen (see shell.qml) and
// only opens on whichever monitor currently has focus, same as the
// wallpaper picker. The grid itself shows every toplevel globally (not
// filtered to the panel's own screen) so you can switch to a window on
// another monitor too. Only verified on a single-monitor machine so far —
// worth a real look on a two-monitor rig: does opening it on monitor B
// while the target window is on monitor A still focus + raise correctly,
// and does the panel itself only ever appear on the focused monitor.
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

    // Toplevel.activate() (wlr-foreign-toplevel-management) only requests
    // surface activation — Hyprland doesn't reliably follow it with a
    // workspace switch, so picking a window on another workspace left you
    // stranded looking at the old one. `hyprctl dispatch focuswindow` is
    // Hyprland-native and does switch workspace + monitor to bring the
    // window into view, which is what a task switcher actually needs.
    function activate(toplevel) {
        if (!toplevel) return
        // HyprlandToplevel.address is the raw hex without Hyprland's own
        // "0x" prefix (e.g. "557d..." not "0x557d...") — dispatch silently
        // fails with "No such window found" without it.
        Hyprland.dispatch("focuswindow address:0x" + toplevel.address)
        root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.78)

        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true; easing.type: Easing.OutCubic }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Hyprland.toplevels.values.length > 0 ? "Windows" : "No windows open"
                color: Config.accent
                font { pixelSize: 17; bold: true; family: root.nfFont }
            }

            GridView {
                id: grid
                readonly property int columns: Math.max(1, Math.min(4, Hyprland.toplevels.values.length))
                Layout.preferredWidth: columns * cellWidth
                Layout.preferredHeight: Math.min(
                    Math.ceil(Hyprland.toplevels.values.length / columns) * cellHeight,
                    root.height - 170)
                Layout.maximumWidth: root.width - 80

                cellWidth: 280
                cellHeight: 205
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
                    readonly property bool picked: cell.hov || cell.selected

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 12
                        radius: 16
                        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.97)
                        border.width: cell.picked ? 2 : 1
                        border.color: cell.picked
                            ? Config.accent
                            : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
                        // Unselected cards recede slightly so the picked one reads
                        // as the obvious next action, not just another tile.
                        opacity: cell.picked ? 1.0 : 0.82
                        scale: cell.picked ? 1.0 : 0.97
                        y: cell.picked ? -4 : 0
                        Behavior on y { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }
                        clip: true

                        ScreencopyView {
                            anchors.fill: parent
                            anchors.margins: 9
                            anchors.bottomMargin: 32
                            captureSource: cell.modelData.wayland
                            // Only stream frames while the overview is actually
                            // on screen — a hidden overlay shouldn't keep
                            // screencopying every window in the background.
                            live: root.visible
                        }

                        // Workspace badge
                        Rectangle {
                            visible: cell.modelData.workspace !== null
                            anchors { top: parent.top; left: parent.left; margins: 9 }
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

                        // Currently-focused-before-opening indicator — a small dot,
                        // not a border, so it never competes visually with the
                        // selection/hover highlight above.
                        Rectangle {
                            visible: cell.modelData.activated
                            anchors { top: parent.top; right: parent.right; margins: 12 }
                            width: 7; height: 7; radius: 3.5
                            color: Config.accent
                        }

                        // Gradient title fade instead of a hard bar — the label reads
                        // as part of the thumbnail, not a strip pasted over it.
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 44
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.8) }
                            }
                            Text {
                                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 8 }
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
