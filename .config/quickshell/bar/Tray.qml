import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// System tray icons (StatusNotifierItem). Populates when apps that use a tray
// are running (Discord, Steam, nm-applet, …). Click an icon → the app's menu
// opens (Windows-style), styled to match; click away to dismiss.
RowLayout {
    id: root
    spacing: 3

    required property var barColors

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry
            required property var modelData

            implicitWidth: 28
            implicitHeight: 28
            Layout.alignment: Qt.AlignVCenter

            property double lastDismiss: 0
            property bool   grabActive:  false

            function closeMenu() {
                trayMenu.visible = false
                entry.grabActive  = false
                entry.lastDismiss = Date.now()
            }

            // grab activates a moment AFTER the popup maps, else the focus-grab
            // races the window creation and never engages (menu won't dismiss)
            Timer { id: grabDelay; interval: 90; onTriggered: entry.grabActive = true }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: (hov.containsMouse || trayMenu.visible)
                       ? Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.07) : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            // icon — with per-app glyph overrides + a fallback when unresolved
            Item {
                id: iconBox
                anchors.centerIn: parent
                width: 18; height: 18

                // override ugly app-supplied icons with a distinct colored logo
                readonly property bool isNet: {
                    var k = (entry.modelData.id || "").toLowerCase()
                    return k === "nm-applet" || k.indexOf("network") !== -1
                }
                readonly property string ovr:      isNet ? "󰑩" : ""     // wireless router
                readonly property color  ovrColor: isNet ? "#94e2d5" : root.barColors.subtext0 // teal

                IconImage {
                    id: ic
                    anchors.fill: parent
                    asynchronous: true
                    source: entry.modelData.icon
                    visible: iconBox.ovr === "" && ic.status === Image.Ready && entry.modelData.icon !== ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: iconBox.ovr !== ""
                    text: iconBox.ovr
                    color: iconBox.ovrColor
                    font.family: root.barColors.nfFont
                    font.pixelSize: 21
                }
                Text {
                    anchors.centerIn: parent
                    visible: iconBox.ovr === "" && !ic.visible
                    text: ""                       // generic fallback glyph
                    color: root.barColors.subtext0
                    font.family: root.barColors.nfFont
                    font.pixelSize: 15
                }
            }

            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    // middle-click → primary activate (open the app window)
                    if (mouse.button === Qt.MiddleButton) {
                        entry.modelData.activate()
                        return
                    }
                    // left/right → toggle the app's menu (fall back to activate)
                    if (trayMenu.visible || Date.now() - entry.lastDismiss < 250) {
                        entry.closeMenu()
                        return
                    }
                    if (entry.modelData.hasMenu) {
                        trayMenu.visible = true
                        grabDelay.restart()
                    } else {
                        entry.modelData.activate()
                    }
                }
            }

            TrayMenu {
                id: trayMenu
                handle: entry.modelData.menu
                barColors: root.barColors
                anchor.item: entry
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom | Edges.Left
                onCloseAll: entry.closeMenu()
            }

            // click-outside dismiss (activated after the popup is mapped)
            HyprlandFocusGrab {
                windows: [trayMenu]
                active: entry.grabActive && trayMenu.visible
                onCleared: entry.closeMenu()
            }
        }
    }
}
