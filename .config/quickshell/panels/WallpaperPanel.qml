import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel

// Visual wallpaper picker — a horizontal filmstrip of thumbnails read live
// from ~/Pictures/Wallpapers (auto-updates when files are added/removed).
// Wheel / arrows to browse, click or Enter to apply via awww. Esc to close.
PanelWindow {
    id: root
    signal close()

    // Hyprland output this picker belongs to (set per-screen from shell.qml).
    // When set, wallpapers are applied to THIS monitor only, so each screen
    // can carry its own wallpaper.
    property string outputName: ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    // Grab the keyboard while open so Esc / arrows / Enter work
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            strip.syncToCurrent()
        } else {
            strip.flickVel = 0
            inertia.acc = 0
            inertia.running = false
        }
    }

    readonly property string nfFont:  "JetBrainsMono Nerd Font Mono"
    readonly property color   text:     "#cdd6f4"
    readonly property color   subtext0: "#a6adc8"
    readonly property color   overlay0: "#6c7086"
    readonly property color   pink:     "#f38ba8"
    readonly property color   mauve:    "#cba6f7"

    // ← adjust these two paths to your home directory
    readonly property string wallDir: "/home/fiw/Pictures/Wallpapers"

    // ── Apply a wallpaper via awww (animated grow transition; handles gifs) ──
    // Apply via awww and record the pick (path passed as $1 to dodge quoting issues)
    Process { id: applyProc }
    function apply(path) {
        if (!path) return
        applyProc.running = false
        // $1 = wallpaper path, $2 = output name (empty → all monitors).
        // When an output is given we target it with `awww -o` and remember
        // this monitor's pick in a per-output cache, while still updating the
        // shared cache hyprlock/SDDM read.
        applyProc.command = ["sh", "-c",
            "if [ -n \"$2\" ]; then OUT=\"-o $2\"; else OUT=\"\"; fi; " +
            "awww img \"$1\" $OUT -t grow --transition-pos 0.5,0.5 --transition-fps 60 " +
            "--transition-duration 1.1 --resize crop && " +
            "printf '%s' \"$1\" > ~/.cache/wallpaper-current; " +
            "[ -n \"$2\" ] && printf '%s' \"$1\" > \"$HOME/.cache/wallpaper-$2\"",
            "sh", path, root.outputName]
        applyProc.running = true
        root.appliedPath = path
        root.close()            // dismiss the picker once a wallpaper is chosen
    }
    property string appliedPath: ""

    // Infinite scroll — wrap past the ends instead of clamping
    function nextWall() { if (wallModel.count > 0) strip.currentIndex = (strip.currentIndex + 1) % wallModel.count }
    function prevWall() { if (wallModel.count > 0) strip.currentIndex = (strip.currentIndex - 1 + wallModel.count) % wallModel.count }

    // Read this monitor's last pick on startup so the strip can highlight it
    // (per-output cache when we know our output, else the shared one). awww's
    // own cache handles the actual wallpaper restore on boot.
    FileView {
        id: currentFile
        path: root.outputName
              ? "/home/fiw/.cache/wallpaper-" + root.outputName
              : "/home/fiw/.cache/wallpaper-current"
        onLoaded: root.appliedPath = text().trim()
    }

    // ── Background scrim (click outside the card to dismiss) ────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0x11/255, 0x11/255, 0x1b/255, 0.45)
        NumberAnimation on opacity { from: 0; to: 1; duration: 160; running: true; easing.type: Easing.OutCubic }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The picker card ─────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 96, 1320)
        height: 380
        radius: 26
        color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.70)
        border.width: 1
        border.color: Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.08)

        // swallow clicks so they don't fall through to the scrim
        MouseArea { anchors.fill: parent }

        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }
        NumberAnimation on scale  { from: 0.96; to: 1; duration: 220; running: true; easing.type: Easing.OutBack }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "󰸉"
                    color: root.mauve
                    font { pixelSize: 22; family: root.nfFont }
                }
                Text {
                    text: "Wallpapers"
                    color: root.text
                    font { pixelSize: 18; bold: true; family: root.nfFont }
                }
                Rectangle {
                    radius: 999; color: Qt.rgba(0xcb/255, 0xa6/255, 0xf7/255, 0.16)
                    implicitWidth: cntTxt.implicitWidth + 16; implicitHeight: 22
                    Text {
                        id: cntTxt; anchors.centerIn: parent
                        text: wallModel.count + " items"
                        color: root.mauve
                        font { pixelSize: 11; family: root.nfFont }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "scroll · click to apply · esc"
                    color: root.overlay0
                    font { pixelSize: 11; family: root.nfFont }
                }
            }

            // Filmstrip — circular carousel: scrolling past the end flows
            // seamlessly back into the start (no rewind jump)
            PathView {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                pathItemCount: 7
                preferredHighlightBegin: 0.5
                preferredHighlightEnd:   0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 150
                snapMode: PathView.SnapToItem

                // straight horizontal track; center item scales up (coverflow feel)
                path: Path {
                    startX: 0; startY: strip.height / 2
                    PathAttribute { name: "iz";       value: 0 }
                    PathAttribute { name: "iscale";   value: 0.78 }
                    PathAttribute { name: "iopacity"; value: 0.45 }
                    PathLine { x: strip.width / 2; y: strip.height / 2 }
                    PathAttribute { name: "iz";       value: 10 }
                    PathAttribute { name: "iscale";   value: 1.15 }
                    PathAttribute { name: "iopacity"; value: 1.0 }
                    PathLine { x: strip.width; y: strip.height / 2 }
                    PathAttribute { name: "iz";       value: 0 }
                    PathAttribute { name: "iscale";   value: 0.78 }
                    PathAttribute { name: "iopacity"; value: 0.45 }
                }

                model: FolderListModel {
                    id: wallModel
                    folder: "file://" + root.wallDir
                    showDirs: false
                    sortField: FolderListModel.Name
                    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp"]
                }

                // jump the highlight to the currently-applied wallpaper
                function syncToCurrent() {
                    if (!root.appliedPath) return
                    for (var i = 0; i < wallModel.count; i++) {
                        if (wallModel.get(i, "filePath") === root.appliedPath) {
                            positionViewAtIndex(i, PathView.Center)
                            currentIndex = i
                            return
                        }
                    }
                }

                // ── Momentum scrolling ──────────────────────────────────────
                // Each wheel notch injects velocity; the timer advances the
                // carousel and decays it, so a fast spin coasts a few wallpapers
                // and glides to a stop (a slow single notch ≈ one step).
                property real flickVel: 0          // items per tick (signed)

                Timer {
                    id: inertia
                    interval: 16; repeat: true; running: false
                    property real acc: 0
                    onTriggered: {
                        inertia.acc += strip.flickVel
                        while (inertia.acc >=  1) { root.nextWall(); inertia.acc -= 1 }
                        while (inertia.acc <= -1) { root.prevWall(); inertia.acc += 1 }
                        strip.flickVel *= 0.90     // friction
                        if (Math.abs(strip.flickVel) < 0.012) {
                            strip.flickVel = 0; inertia.acc = 0; inertia.running = false
                        }
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => {
                        var dir = (e.angleDelta.y < 0 || e.angleDelta.x < 0) ? 1 : -1
                        var mag = Math.min(Math.abs(e.angleDelta.y) || 120, 360) / 120
                        strip.flickVel += dir * mag * 0.10
                        strip.flickVel = Math.max(-0.8, Math.min(0.8, strip.flickVel))
                        inertia.running = true
                    }
                }

                delegate: Item {
                    id: cell
                    required property int index
                    required property url fileUrl
                    required property string filePath
                    required property string fileName

                    width: 248
                    height: strip.height
                    scale:   cell.PathView.iscale   ?? 0.78
                    opacity: cell.PathView.iopacity ?? 0.45
                    z:       cell.PathView.iz        ?? 0

                    Item {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: 12

                        readonly property int rad: 16

                        // rounded dark backing (shows through any letterboxing)
                        Rectangle { anchors.fill: parent; radius: frame.rad; color: "#181825" }

                        // wallpaper masked to rounded corners
                        Image {
                            id: wpImg
                            anchors.fill: parent
                            source: cell.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 420
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: wpImg
                            maskEnabled: true
                            maskSource: wpMask
                        }
                        Item {
                            id: wpMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: frame.rad; color: "black"; antialiasing: true }
                        }

                        // rounded border on top
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.rad
                            color: "transparent"
                            antialiasing: true
                            border.width: cell.PathView.isCurrentItem ? 3 : 1
                            border.color: cell.PathView.isCurrentItem
                                          ? (cell.filePath === root.appliedPath ? root.mauve : root.pink)
                                          : Qt.rgba(0xcd/255, 0xd6/255, 0xf4/255, 0.10)
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                        }

                        // "active" badge on the wallpaper that's currently set
                        Rectangle {
                            visible: cell.filePath === root.appliedPath
                            anchors { top: parent.top; right: parent.right; margins: 8 }
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(0x1e/255, 0x1e/255, 0x2e/255, 0.85)
                            Text {
                                anchors.centerIn: parent; text: "󰄬"
                                color: root.mauve; font { pixelSize: 14; family: root.nfFont }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            strip.currentIndex = cell.index
                            root.apply(cell.filePath)
                        }
                    }
                }
            }

            // Footer — name of the centered wallpaper
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (wallModel.count === 0) return "No wallpapers in " + root.wallDir
                    var n = wallModel.get(strip.currentIndex, "fileName")
                    return n ? n : ""
                }
                color: root.subtext0
                font { pixelSize: 12; family: root.nfFont }
            }
        }
    }

    // ── Keyboard ─────────────────────────────────────────────────────────────
    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            switch (ev.key) {
                case Qt.Key_Escape: root.close(); break
                case Qt.Key_Left:   root.prevWall(); break
                case Qt.Key_Right:  root.nextWall(); break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.apply(wallModel.get(strip.currentIndex, "filePath")); break
            }
        }
    }
}
