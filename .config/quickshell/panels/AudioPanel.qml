import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    signal close()
    signal showOsd(string kind, real value)

    anchors { top: true; right: true }
    margins.top: 42
    exclusiveZone: 0
    implicitWidth: 340
    implicitHeight: audioContent.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color subtext0: "#a6adc8"
    readonly property color text:     "#cdd6f4"
    readonly property color pink:     "#f38ba8"
    readonly property color teal:     "#94e2d5"

    function fmtTime(s) {
        if (!s || s < 0 || !isFinite(s)) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    // app id → nerd-font glyph + friendly name
    function appIcon(p) {
        var id = ((p.identity ?? "") + " " + (p.desktopEntry ?? "")).toLowerCase()
        if (id.includes("spotify"))                         return ""
        if (id.includes("firefox") || id.includes("zen"))   return ""
        if (id.includes("chrom") || id.includes("brave"))   return ""
        if (id.includes("vlc"))                             return "󰕼"
        if (id.includes("mpv"))                             return ""
        if (id.includes("youtube"))                         return ""
        if (id.includes("mpd") || id.includes("ncmpcpp"))   return ""
        if (id.includes("kdenlive") || id.includes("obs"))  return "󰕧"
        if (id.includes("plasma") || id.includes("kde"))    return ""
        return "󰎈"
    }

    PwObjectTracker {
        objects: {
            var objs = []
            if (Pipewire.defaultAudioSink) objs.push(Pipewire.defaultAudioSink)
            if (Pipewire.defaultAudioSource) objs.push(Pipewire.defaultAudioSource)
            return objs
        }
    }

    Rectangle {
        id: audioContent
        width: parent.width
        implicitHeight: audioCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        ColumnLayout {
            id: audioCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "AUDIO"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }
                Text { text: "󰘮"; color: root.pink; font { pixelSize: 18; family: root.nfFont } }
            }

            // ── Now Playing ───────────────────────────────────────────────
            Repeater {
                model: Mpris.players
                delegate: Rectangle {
                    id: playerCard
                    required property MprisPlayer modelData
                    Layout.fillWidth: true
                    implicitHeight: cardCol.implicitHeight + 26
                    radius: 0
                    color: "transparent"

                    // Force position to refresh while playing (position is lazily reactive)
                    Timer {
                        interval: 1000; repeat: true
                        running: playerCard.modelData.isPlaying
                        onTriggered: playerCard.modelData.positionChanged()
                    }

                    // subtle top separator
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 1
                        color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.06)
                    }

                    ColumnLayout {
                        id: cardCol
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18; topMargin: 14; bottomMargin: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            // Album art
                            Rectangle {
                                width: 58; height: 58; radius: 13
                                color: root.surface1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: playerCard.modelData.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: (playerCard.modelData.trackArtUrl ?? "") !== ""
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: (playerCard.modelData.trackArtUrl ?? "") === ""
                                    text: root.appIcon(playerCard.modelData)
                                    color: root.overlay0
                                    font { pixelSize: 26; family: root.nfFont }
                                }
                            }

                            // Info
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // Source app + title row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: root.appIcon(playerCard.modelData)
                                        color: root.pink
                                        font { pixelSize: 13; family: root.nfFont }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: playerCard.modelData.trackTitle || playerCard.modelData.identity || "Unknown"
                                        color: root.text
                                        font { pixelSize: 12; bold: true; family: root.nfFont }
                                        elide: Text.ElideRight
                                    }
                                }

                                // Artist · album
                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        var a = playerCard.modelData.trackArtist || ""
                                        var al = playerCard.modelData.trackAlbum || ""
                                        return al && a ? a + " · " + al : (a || al)
                                    }
                                    color: root.overlay0
                                    font { pixelSize: 10; family: root.nfFont }
                                    elide: Text.ElideRight
                                    visible: text !== ""
                                }

                                // Source name (firefox / spotify / mpv …)
                                Text {
                                    text: playerCard.modelData.identity || ""
                                    color: root.overlay1
                                    font { pixelSize: 9; family: root.nfFont }
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }
                        }

                        // ── Seek bar + times ─────────────────────────────────
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            visible: playerCard.modelData.lengthSupported && playerCard.modelData.length > 0

                            Item {
                                Layout.fillWidth: true; height: 6

                                Rectangle { anchors.fill: parent; radius: 99; color: root.surface2 }
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1,
                                            playerCard.modelData.position / Math.max(1, playerCard.modelData.length)))
                                    height: 6; radius: 99; color: root.pink
                                }
                                Rectangle {
                                    x: parent.width * Math.max(0, Math.min(1,
                                            playerCard.modelData.position / Math.max(1, playerCard.modelData.length))) - 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 12; height: 12; radius: 6; color: root.text
                                    visible: playerCard.modelData.canSeek
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: playerCard.modelData.canSeek
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: mouse => {
                                        var frac = Math.max(0, Math.min(1, mouse.x / parent.width))
                                        var target = frac * playerCard.modelData.length
                                        playerCard.modelData.seek(target - playerCard.modelData.position)
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: root.fmtTime(playerCard.modelData.position)
                                    color: root.overlay0
                                    font { pixelSize: 9; family: root.nfFont }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: root.fmtTime(playerCard.modelData.length)
                                    color: root.overlay0
                                    font { pixelSize: 9; family: root.nfFont }
                                }
                            }
                        }

                        // ── Controls ─────────────────────────────────────────
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6

                            // Previous / back
                            Rectangle {
                                width: 30; height: 30; radius: 9
                                color: prevHov.containsMouse ? root.surface1 : "transparent"
                                opacity: playerCard.modelData.canGoPrevious ? 1 : 0.3
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮"
                                    color: root.subtext0
                                    font { pixelSize: 15; family: root.nfFont }
                                }
                                MouseArea {
                                    id: prevHov
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: playerCard.modelData.canGoPrevious
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: playerCard.modelData.previous()
                                }
                            }

                            // Play / Pause (resume)
                            Rectangle {
                                width: 36; height: 36; radius: 10
                                color: playHov.containsMouse
                                       ? Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.22)
                                       : Qt.rgba(0xf3/255,0x8b/255,0xa8/255,0.12)
                                opacity: playerCard.modelData.canTogglePlaying ? 1 : 0.3
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: playerCard.modelData.isPlaying ? "󰏤" : "󰐊"
                                    color: root.pink
                                    font { pixelSize: 17; family: root.nfFont }
                                }
                                MouseArea {
                                    id: playHov
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: playerCard.modelData.canTogglePlaying
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: playerCard.modelData.togglePlaying()
                                }
                            }

                            // Stop
                            Rectangle {
                                width: 30; height: 30; radius: 9
                                color: stopHov.containsMouse ? root.surface1 : "transparent"
                                opacity: playerCard.modelData.canControl ? 1 : 0.3
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰓛"
                                    color: root.subtext0
                                    font { pixelSize: 14; family: root.nfFont }
                                }
                                MouseArea {
                                    id: stopHov
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: playerCard.modelData.canControl
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: playerCard.modelData.stop()
                                }
                            }

                            // Next / forward
                            Rectangle {
                                width: 30; height: 30; radius: 9
                                color: nextHov.containsMouse ? root.surface1 : "transparent"
                                opacity: playerCard.modelData.canGoNext ? 1 : 0.3
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    color: root.subtext0
                                    font { pixelSize: 15; family: root.nfFont }
                                }
                                MouseArea {
                                    id: nextHov
                                    anchors.fill: parent; hoverEnabled: true
                                    enabled: playerCard.modelData.canGoNext
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: playerCard.modelData.next()
                                }
                            }
                        }
                    }
                }
            }

            // Empty state — nothing playing
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 18; Layout.rightMargin: 18
                Layout.topMargin: 6; Layout.bottomMargin: 6
                spacing: 10
                visible: Mpris.players.values.length === 0

                Text { text: "󰎊"; color: root.overlay0; font { pixelSize: 18; family: root.nfFont } }
                Text {
                    Layout.fillWidth: true
                    text: "Nothing playing"
                    color: root.overlay0
                    font { pixelSize: 11; family: root.nfFont }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 8

                // Output device label
                Text {
                    text: Pipewire.defaultAudioSink?.description ?? Pipewire.defaultAudioSink?.name ?? "Output"
                    color: root.overlay1
                    font { pixelSize: 10; family: root.nfFont }
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Master volume slider
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 16; color: root.surface0

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 13

                        Text {
                            text: (Pipewire.defaultAudioSink?.audio?.muted || (Pipewire.defaultAudioSink?.audio?.volume ?? 0) === 0) ? "󰖁" : "󰕾"
                            color: root.subtext0
                            font { pixelSize: 20; family: root.nfFont }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (Pipewire.defaultAudioSink?.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                            }
                        }

                        Item {
                            Layout.fillWidth: true; height: 8

                            Rectangle { anchors.fill: parent; radius: 99; color: root.surface2 }
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSink?.audio?.volume ?? 0))
                                height: 8; radius: 99; color: root.pink
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                            Rectangle {
                                x: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSink?.audio?.volume ?? 0)) - 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8; color: root.text
                            }

                            MouseArea {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 26
                                cursorShape: Qt.PointingHandCursor
                                function setVol(mx) {
                                    var v = Math.max(0, Math.min(1, mx / width))
                                    if (Pipewire.defaultAudioSink?.audio) {
                                        Pipewire.defaultAudioSink.audio.volume = v
                                        root.showOsd("volume", Math.round(v * 100))
                                    }
                                }
                                onPressed: mouse => setVol(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setVol(mouse.x) }
                            }
                        }

                        Text {
                            text: Math.round((Pipewire.defaultAudioSink?.audio?.volume ?? 0) * 100) + "%"
                            color: root.subtext0
                            font { pixelSize: 12; bold: true; family: root.nfFont }
                            width: 36; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Text { text: "Output · master volume"; color: root.overlay0; font { pixelSize: 10; family: root.nfFont } Layout.leftMargin: 4 }

                // Mic slider
                Rectangle {
                    Layout.fillWidth: true; height: 52; radius: 16; color: root.surface0
                    visible: Pipewire.defaultAudioSource !== null

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 13

                        Text {
                            text: (Pipewire.defaultAudioSource?.audio?.muted) ? "󰄱" : "󰄰"
                            color: root.teal
                            font { pixelSize: 20; family: root.nfFont }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (Pipewire.defaultAudioSource?.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                            }
                        }

                        Item {
                            Layout.fillWidth: true; height: 8

                            Rectangle { anchors.fill: parent; radius: 99; color: root.surface2 }
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSource?.audio?.volume ?? 0))
                                height: 8; radius: 99; color: root.teal
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                            Rectangle {
                                x: parent.width * Math.max(0, Math.min(1, Pipewire.defaultAudioSource?.audio?.volume ?? 0)) - 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; radius: 8; color: root.text
                            }

                            MouseArea {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 26
                                cursorShape: Qt.PointingHandCursor
                                function setVol(mx) {
                                    var v = Math.max(0, Math.min(1, mx / width))
                                    if (Pipewire.defaultAudioSource?.audio) Pipewire.defaultAudioSource.audio.volume = v
                                }
                                onPressed: mouse => setVol(mouse.x)
                                onPositionChanged: mouse => { if (pressed) setVol(mouse.x) }
                            }
                        }

                        Text {
                            text: Math.round((Pipewire.defaultAudioSource?.audio?.volume ?? 0) * 100) + "%"
                            color: root.subtext0
                            font { pixelSize: 12; bold: true; family: root.nfFont }
                            width: 36; horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                Text { text: "Input · microphone"; color: root.overlay0; font { pixelSize: 10; family: root.nfFont } Layout.leftMargin: 4; visible: Pipewire.defaultAudioSource !== null }

                Item { implicitHeight: 4 }
            }
        }
    }
}
