import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    // Grab the keyboard while the menu is up so Esc / L / E / S / R / P work
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) keyHandler.forceActiveFocus()

    function run(cmd) {
        Qt.createQmlObject(
            'import Quickshell.Io; Process { command: ["sh","-c","' + cmd + '"]; running: true }',
            root)
        root.close()
    }

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0x11/255, 0x11/255, 0x1b/255, 0.7)

        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true; easing.type: Easing.OutCubic }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        RowLayout {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: [
                    { label: "Lock",     icon: "",    color: "#89b4fa", key: "L", cmd: "hyprlock" },
                    { label: "Logout",   icon: "󰍃",  color: "#cba6f7", key: "E", cmd: "hyprctl dispatch exit" },
                    { label: "Sleep",    icon: "󰯙",   color: "#94e2d5", key: "S", cmd: "systemctl suspend" },
                    { label: "Reboot",   icon: "󰔉",  color: "#f9e2af", key: "R", cmd: "systemctl reboot" },
                    { label: "Shutdown", icon: "",   color: "#f38ba8", key: "P", cmd: "systemctl poweroff" },
                ]

                delegate: Item {
                    id: pwBtn
                    required property var modelData
                    implicitWidth: 128; implicitHeight: 138
                    property bool hov: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 22
                        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.96)
                        border.width: 1
                        border.color: pwBtn.hov ? pwBtn.modelData.color : Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
                        y: pwBtn.hov ? -6 : 0
                        Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 140 } }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 24; width: 58; height: 58; radius: 18
                            color: Qt.rgba(0x11/255, 0x11/255, 0x1b/255, 0.4)
                            Text {
                                anchors.centerIn: parent
                                text: pwBtn.modelData.icon
                                color: pwBtn.modelData.color
                                font { pixelSize: 28; family: root.nfFont }
                            }
                        }

                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 20 }
                            text: pwBtn.modelData.label
                            color: "#cdd6f4"
                            font { pixelSize: 13; bold: true; family: root.nfFont }
                        }

                        Rectangle {
                            anchors { top: parent.top; right: parent.right; margins: 10 }
                            width: 20; height: 18; radius: 6
                            color: "#313244"
                            border.width: 1
                            border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.07)
                            Text {
                                anchors.centerIn: parent
                                text: pwBtn.modelData.key
                                color: "#a6adc8"
                                font { pixelSize: 10; family: root.nfFont }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: pwBtn.hov = true
                        onExited:  pwBtn.hov = false
                        onClicked: root.run(pwBtn.modelData.cmd)
                    }
                }
            }
        }
    }

    // Keyboard handler
    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            switch(ev.key) {
                case Qt.Key_Escape: root.close(); break
                case Qt.Key_L: root.run("hyprlock"); break
                case Qt.Key_E: root.run("hyprctl dispatch exit"); break
                case Qt.Key_S: root.run("systemctl suspend"); break
                case Qt.Key_R: root.run("systemctl reboot"); break
                case Qt.Key_P: root.run("systemctl poweroff"); break
            }
        }
    }
}
