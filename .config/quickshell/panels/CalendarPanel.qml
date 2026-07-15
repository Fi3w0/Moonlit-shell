import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../services"

PanelWindow {
    id: root
    signal close()
    signal clearNotifs()
    signal dismissNotif(var nid)

    required property var notifications
    required property var removeNotifFunc
    readonly property int notifCount: notifications ? notifications.length : 0

    // Reference date for the mini-calendar. Bumped by the clock tick when the
    // day actually changes, so the grid rolls over at midnight if the panel is
    // left open (and refreshes on reopen) instead of being frozen at whatever
    // day it was first built.
    property var calDate: new Date()

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 42 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
    exclusiveZone: 0
    implicitWidth: 372
    implicitHeight: content.height + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color  base:     Config.base
    readonly property color  mantle:   Config.mantle
    readonly property color  surface0: Config.surface0
    readonly property color  surface1: Config.surface1
    readonly property color  surface2: Config.surface2
    readonly property color  overlay0: Config.overlay0
    readonly property color  overlay1: Config.overlay1
    readonly property color  subtext0: Config.subtext0
    readonly property color  text:     Config.text
    readonly property color  accent:     Config.accent
    readonly property color  green:    "#a6e3a1"
    readonly property color  mauve:    Config.accent

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
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
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
                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.08)
                }

                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 20 }
                    spacing: 4

                    Text {
                        id: bigClock
                        color: root.text
                        font { pixelSize: 40; bold: true; family: root.nfFont }
                        Timer {
                            interval: 1000; running: root.visible; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                var now = new Date()
                                bigClock.text = Qt.formatDateTime(now, "hh:mm:ss")
                                dateLabel.text = Qt.formatDateTime(now, "dddd, MMMM d")
                                yearLabel.text = Qt.formatDateTime(now, "yyyy")
                                if (now.getDate() !== root.calDate.getDate() ||
                                    now.getMonth() !== root.calDate.getMonth() ||
                                    now.getFullYear() !== root.calDate.getFullYear())
                                    root.calDate = now
                            }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Text { id: dateLabel; color: root.subtext0; font { pixelSize: 13; family: root.nfFont } }
                        Text { id: yearLabel; color: root.accent;     font { pixelSize: 13; bold: true; family: root.nfFont } }
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
                        id: dayGrid
                        columns: 7
                        spacing: 0

                        property int  _today:     root.calDate.getDate()
                        property int  _totalDays: new Date(root.calDate.getFullYear(), root.calDate.getMonth()+1, 0).getDate()
                        property int  _firstDay:  (new Date(root.calDate.getFullYear(), root.calDate.getMonth(), 1).getDay() + 6) % 7 // Mon=0

                        Repeater {
                            model: dayGrid._firstDay + dayGrid._totalDays
                            delegate: Item {
                                required property int index
                                property int day: index - dayGrid._firstDay + 1
                                property bool valid: day >= 1
                                property bool today: day === dayGrid._today

                                width: (372 - 32) / 7; height: 34

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 28; height: 28; radius: 9
                                    color: parent.today ? root.accent : "transparent"
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
                id: notifRoot
                Layout.fillWidth: true
                implicitHeight: notifSect.implicitHeight + 12
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
                        Rectangle {
                            visible: root.notifCount > 0
                            radius: 999
                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14)
                            implicitWidth: notifCountText.implicitWidth + 14
                            implicitHeight: 20
                            Text {
                                id: notifCountText
                                anchors.centerIn: parent
                                text: root.notifCount
                                color: root.mauve
                                font { pixelSize: 10; bold: true; family: root.nfFont }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: root.notifCount > 0
                            radius: 999
                            color: clearHov.containsMouse ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.14) : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.22)
                            implicitWidth: clearTxt.implicitWidth + 18
                            implicitHeight: 24
                            Text {
                                id: clearTxt
                                anchors.centerIn: parent
                                text: "Clear"
                                color: root.accent
                                font { pixelSize: 11; bold: true; family: root.nfFont }
                            }
                            MouseArea {
                                id: clearHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.clearNotifs()
                            }
                        }
                    }

                    // Empty state
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 60
                        visible: root.notifCount === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰂛"
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

                    Flickable {
                        Layout.fillWidth: true
                        implicitHeight: Math.min(Math.max(root.notifCount * 84 - 8, 76), 260)
                        visible: root.notifCount > 0
                        clip: true
                        contentHeight: notifList.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: notifList
                            width: parent.width
                            spacing: 8
                            move: Transition {
                                NumberAnimation { properties: "y"; duration: 190; easing.type: Easing.OutCubic }
                            }

                            Repeater {
                                model: root.notifications
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    property bool entered: false

                                    width: notifList.width
                                    height: 76
                                    implicitHeight: height
                                    radius: 14
                                    color: root.surface0
                                    border.width: 1
                                    border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.06)
                                    opacity: modelData.closing ? 0 : (entered ? 1 : 0)
                                    x: modelData.closing ? width + 28 : 0
                                    clip: true

                                    Component.onCompleted: entered = true
                                    Behavior on x { NumberAnimation { duration: 230; easing.type: Easing.InOutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 210; easing.type: modelData.closing ? Easing.InCubic : Easing.OutCubic } }
                                    Timer {
                                        interval: 260
                                        running: modelData.closing
                                        onTriggered: root.removeNotifFunc(modelData.nid)
                                    }

                                    RowLayout {
                                        anchors { fill: parent; margins: 11 }
                                        spacing: 10

                                        Rectangle {
                                            width: 32; height: 32; radius: 10
                                            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
                                            Layout.alignment: Qt.AlignTop

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰂚"
                                                color: root.accent
                                                font { pixelSize: 15; family: root.nfFont }
                                            }
                                        }

                                        ColumnLayout {
                                            id: nfBody
                                            spacing: 3
                                            Layout.fillWidth: true

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: modelData.app || "Notification"
                                                    color: root.subtext0
                                                    font { pixelSize: 10; bold: true; family: root.nfFont }
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: modelData.time
                                                    color: root.overlay0
                                                    font { pixelSize: 10; family: root.nfFont }
                                                }
                                            }
                                            Text {
                                                text: modelData.title
                                                color: root.text
                                                font { pixelSize: 12; bold: true; family: root.nfFont }
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: modelData.body
                                                color: root.subtext0
                                                font { pixelSize: 11; family: root.nfFont }
                                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                maximumLineCount: 4
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: "󰅖"
                                            color: closeHov.containsMouse ? root.accent : root.overlay0
                                            font { pixelSize: 14; family: root.nfFont }
                                            Layout.alignment: Qt.AlignTop

                                            MouseArea {
                                                id: closeHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.dismissNotif(modelData.nid)
                                            }
                                        }
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
