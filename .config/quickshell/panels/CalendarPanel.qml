import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()
    signal clearNotifs()
    signal dismissNotif(int index)

    required property var notifModel

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 372
    implicitHeight: content.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color  base:     "#1e1e2e"
    readonly property color  mantle:   "#181825"
    readonly property color  surface0: "#313244"
    readonly property color  surface1: "#45475a"
    readonly property color  surface2: "#585b70"
    readonly property color  overlay0: "#6c7086"
    readonly property color  overlay1: "#7f849c"
    readonly property color  subtext0: "#a6adc8"
    readonly property color  text:     "#cdd6f4"
    readonly property color  pink:     "#f38ba8"
    readonly property color  green:    "#a6e3a1"
    readonly property color  mauve:    "#cba6f7"

    // Active MPRIS player
    readonly property var player: {
        for (var i = 0; i < Mpris.players.count; i++) {
            var p = Mpris.players.get(i)
            if (p && p.isPlaying) return p
        }
        return Mpris.players.count > 0 ? Mpris.players.get(0) : null
    }

    Rectangle {
        id: content
        width: parent.width
        implicitHeight: col.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        // top-right corner fix
        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }

        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: col
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // ── Clock header ─────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: 100

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0xf3/255, 0x8b/255, 0xa8/255, 0.08)
                }

                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 20 }
                    spacing: 4

                    Text {
                        id: bigClock
                        color: root.text
                        font { pixelSize: 40; bold: true; family: root.nfFont }
                        Timer {
                            interval: 1000; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                bigClock.text = Qt.formatDateTime(new Date(), "hh:mm:ss")
                                dateLabel.text = Qt.formatDateTime(new Date(), "dddd, MMMM d")
                                yearLabel.text = Qt.formatDateTime(new Date(), "yyyy")
                            }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Text { id: dateLabel; color: root.subtext0; font { pixelSize: 13; family: root.nfFont } }
                        Text { id: yearLabel; color: root.pink;     font { pixelSize: 13; bold: true; family: root.nfFont } }
                    }
                }
            }

            // ── Mini calendar ─────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: calGrid.implicitHeight + 20

                ColumnLayout {
                    id: calGrid
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 12 }
                    spacing: 2

                    // Day headers
                    Row {
                        spacing: 0
                        Repeater {
                            model: ["M","T","W","T","F","S","S"]
                            delegate: Text {
                                required property var modelData
                                width: (372 - 32) / 7
                                text: modelData
                                color: root.overlay0
                                font { pixelSize: 10; bold: true; family: root.nfFont }
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Day cells — computed from current date
                    Grid {
                        columns: 7
                        spacing: 0

                        property int  _today:     new Date().getDate()
                        property int  _totalDays: new Date(new Date().getFullYear(), new Date().getMonth()+1, 0).getDate()
                        property int  _firstDay:  (new Date(new Date().getFullYear(), new Date().getMonth(), 1).getDay() + 6) % 7 // Mon=0

                        Repeater {
                            model: parent._firstDay + parent._totalDays
                            delegate: Item {
                                required property int index
                                property int day: index - calGrid.children[1]._firstDay + 1
                                property bool valid: day >= 1
                                property bool today: day === calGrid.children[1]._today

                                width: (372 - 32) / 7; height: 34

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28; height: 28; radius: 9
                                    color: parent.today ? root.pink : "transparent"
                                    visible: parent.valid
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.valid ? parent.day : ""
                                    color: parent.today ? root.base : root.subtext0
                                    font { pixelSize: 12; bold: parent.today; family: root.nfFont }
                                }
                            }
                        }
                    }
                }
            }

            // ── Now Playing ───────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: root.player ? 80 : 0
                visible: root.player !== null
                clip: true

                Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 0; bottomMargin: 8 }
                    radius: 16
                    color: root.surface0

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 12

                        // Art placeholder
                        Rectangle {
                            width: 48; height: 48; radius: 12
                            color: Qt.rgba(0xa6/255, 0xe3/255, 0xa1/255, 0.14)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: root.green
                                font { pixelSize: 22; family: root.nfFont }
                            }
                        }

                        // Track info
                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true

                            Text {
                                text: root.player?.trackTitle ?? ""
                                color: root.text
                                font { pixelSize: 13; bold: true; family: root.nfFont }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: root.player?.trackArtist ?? ""
                                color: root.subtext0
                                font { pixelSize: 11; family: root.nfFont }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Controls
                        RowLayout {
                            spacing: 2

                            Repeater {
                                model: [
                                    { icon: "󰕐",  action: "previous" },
                                    { icon: root.player?.isPlaying ? "󰔾" : "󰕀", action: "playpause" },
                                    { icon: "󰕎",  action: "next" },
                                ]
                                delegate: Item {
                                    required property var modelData
                                    width: 32; height: 32

                                    Rectangle {
                                        anchors.fill: parent; radius: 9
                                        color: ctrlHov.containsMouse ? root.surface1 : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData.icon
                                        color: root.text
                                        font { pixelSize: 16; family: root.nfFont }
                                    }
                                    MouseArea {
                                        id: ctrlHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var act = parent.modelData.action
                                            if (act === "playpause" && root.player) root.player.togglePlaying()
                                            else if (act === "next"  && root.player) root.player.next()
                                            else if (act === "previous" && root.player) root.player.previous()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Notifications ────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: notifSect.implicitHeight + 8

                ColumnLayout {
                    id: notifSect
                    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16 }
                    spacing: 8

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "NOTIFICATIONS"
                            color: root.subtext0
                            font { pixelSize: 11; bold: true; family: root.nfFont }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Clear all"
                            color: root.pink
                            font { pixelSize: 11; family: root.nfFont }
                            visible: (notifModel ? notifModel.count : 0) > 0
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearNotifs()
                            }
                        }
                    }

                    // Empty state
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 60
                        visible: !notifModel || notifModel.count === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰂚_OFF"
                                color: root.overlay0
                                font { pixelSize: 28; family: root.nfFont }
                                opacity: 0.6
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "You're all caught up"
                                color: root.overlay0
                                font { pixelSize: 12; family: root.nfFont }
                            }
                        }
                    }

                    // Notification items
                    Repeater {
                        model: notifModel
                        delegate: Rectangle {
                            required property var model
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: nfBody.implicitHeight + 24
                            radius: 16
                            color: root.surface0

                            RowLayout {
                                anchors { fill: parent; margins: 12 }
                                spacing: 11

                                Rectangle {
                                    width: 36; height: 36; radius: 11
                                    color: Qt.rgba(0xf3/255, 0x8b/255, 0xa8/255, 0.18)
                                    Layout.alignment: Qt.AlignTop

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂚"
                                        color: root.pink
                                        font { pixelSize: 17; family: root.nfFont }
                                    }
                                }

                                ColumnLayout {
                                    id: nfBody
                                    spacing: 2
                                    Layout.fillWidth: true

                                    RowLayout {
                                        Text {
                                            text: model.app
                                            color: root.subtext0
                                            font { pixelSize: 10; bold: true; family: root.nfFont }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: model.time
                                            color: root.overlay0
                                            font { pixelSize: 10; family: root.nfFont }
                                        }
                                    }
                                    Text {
                                        text: model.title
                                        color: root.text
                                        font { pixelSize: 13; bold: true; family: root.nfFont }
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: model.body
                                        color: root.subtext0
                                        font { pixelSize: 12; family: root.nfFont }
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                        Layout.fillWidth: true
                                    }
                                }

                                Text {
                                    text: "󰅖"
                                    color: root.overlay0
                                    font { pixelSize: 14; family: root.nfFont }
                                    Layout.alignment: Qt.AlignTop

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.dismissNotif(parent.parent.parent.index)
                                    }
                                }
                            }
                        }
                    }

                    Item { implicitHeight: 4 }
                }
            }
        }
    }
}
