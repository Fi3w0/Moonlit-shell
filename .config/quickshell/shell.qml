import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "bar"
import "panels"

ShellRoot {
    // Global notification list (shared across all screen instances)
    ListModel { id: notifModel }
    property var notifItems: []

    Timer {
        id: clearNotifTimer
        interval: 300
        repeat: false
        onTriggered: {
            notifModel.clear()
            notifItems = []
        }
    }

    function pushNotification(app, title, body) {
        var item = {
            nid: Date.now(),
            app: app || "Moonlit",
            title: title || "",
            body: body || "",
            time: Qt.formatDateTime(new Date(), "hh:mm"),
            closing: false
        }
        notifModel.insert(0, item)
        var next = notifItems.slice()
        next.unshift(item)
        while (next.length > 50)
            next.pop()
        notifItems = next
        while (notifModel.count > 50)
            notifModel.remove(notifModel.count - 1)
    }

    function setNotificationClosing(nid) {
        var next = notifItems.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].nid === nid) {
                var item = {}
                for (var key in next[i])
                    item[key] = next[i][key]
                item.closing = true
                next[i] = item
                notifItems = next
                for (var j = 0; j < notifModel.count; j++) {
                    if (notifModel.get(j).nid === nid) {
                        notifModel.setProperty(j, "closing", true)
                        break
                    }
                }
                break
            }
        }
    }

    function removeNotification(nid) {
        var next = []
        for (var i = 0; i < notifItems.length; i++) {
            if (notifItems[i].nid !== nid)
                next.push(notifItems[i])
        }
        notifItems = next
        for (var j = 0; j < notifModel.count; j++) {
            if (notifModel.get(j).nid === nid) {
                notifModel.remove(j)
                break
            }
        }
    }

    NotificationServer {
        keepOnReload: true
        onNotification: notif => {
            pushNotification(notif.appName, notif.summary, notif.body)
            // Forward to toast stacks unless Do Not Disturb is on
            // (notification still lands in the center via notifModel above)
            if (!sys.dnd)
                toastRelay.notify(notif.appName, notif.summary, notif.body)
        }
    }

    // Global quick-settings state, shared across every screen
    QtObject {
        id: sys
        property bool dnd:        false   // suppress notification pop-ups
        property bool caffeine:   false   // inhibit idle / keep awake
        property bool nightLight: false   // warm color filter
    }

    // Warm "night light" filter — quickshell runs/stops hyprsunset with the toggle
    Process {
        id: nightProc
        command: ["hyprsunset", "-t", "4500"]
        running: sys.nightLight
    }

    // ── Shared, machine-wide stats + status pollers ──────────────────────
    // These used to live inside Bar.qml, so every monitor ran its own battery /
    // update / recording polls and could fire duplicate toasts. Hoisted here so
    // they run exactly once; each screen's Bar binds to these values via its
    // `shared` property.
    QtObject {
        id: sharedSys

        property real   battPct:           100
        property bool   battCharging:       false
        property int    updateCount:        0
        property int    pacmanUpdateCount:  0
        property int    aurUpdateCount:     0
        property string aurHelper:          ""
        property bool   recordingActive:    false
        property bool   tempWarned:         false

        // CPU/RAM/WiFi/temp — one instance for the whole shell.
        property var stats: SystemStats { }

        // Battery via sysfs.
        property var battProc: Process {
            command: ["sh", "-c", "paste <(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100) <(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo Unknown)"]
            stdout: SplitParser {
                onRead: d => {
                    var p = d.trim().split("\t")
                    if (p.length >= 2) {
                        var n = parseInt(p[0])
                        if (!isNaN(n)) sharedSys.battPct = n
                        var s = p[1].trim()
                        sharedSys.battCharging = (s === "Charging" || s === "Full")
                    }
                }
            }
            running: true
        }
        property var battTimer: Timer { interval: 30000; running: true; repeat: true; onTriggered: sharedSys.battProc.running = true }

        // Pending updates (pacman + AUR helper).
        property var updateProc: Process {
            command: ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then p=$(checkupdates 2>/dev/null | wc -l); else p=$(pacman -Qu 2>/dev/null | wc -l); fi; if command -v paru >/dev/null 2>&1; then h=paru; a=$(paru -Qua 2>/dev/null | wc -l); elif command -v yay >/dev/null 2>&1; then h=yay; a=$(yay -Qua 2>/dev/null | wc -l); else h=; a=0; fi; printf '%s %s %s\\n' \"$p\" \"$a\" \"$h\""]
            stdout: SplitParser {
                onRead: d => {
                    var p = d.trim().split(/\s+/)
                    sharedSys.pacmanUpdateCount = parseInt(p[0]) || 0
                    sharedSys.aurUpdateCount = parseInt(p[1]) || 0
                    sharedSys.aurHelper = p.length >= 3 ? p[2] : ""
                    sharedSys.updateCount = sharedSys.pacmanUpdateCount + sharedSys.aurUpdateCount
                }
            }
        }
        property var updateTimer: Timer {
            interval: 1800000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: sharedSys.updateProc.running = true
        }
        // Debounce: re-check a few seconds after a pacman transaction settles.
        property var updateRecheck: Timer {
            interval: 4000; repeat: false
            onTriggered: sharedSys.updateProc.running = true
        }
        // Re-run the check whenever pacman writes to its log.
        property var pacmanLog: FileView {
            path: "/var/log/pacman.log"
            watchChanges: true
            onFileChanged: sharedSys.updateRecheck.restart()
        }

        // Screen-recording indicator.
        property var recordingProc: Process {
            command: ["sh", "-c", "pgrep -x 'obs|wf-recorder|gpu-screen-recorder|kooha|simplescreenrecorder' >/dev/null && echo 1 || echo 0"]
            stdout: SplitParser { onRead: d => sharedSys.recordingActive = d.trim() === "1" }
        }
        property var recordingTimer: Timer {
            interval: 10000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: sharedSys.recordingProc.running = true
        }

        // Wake detector: QML timers pause during suspend, so on resume the
        // wall-clock jumps far more than the tick interval. When it does, the
        // machine just woke -> refresh everything immediately.
        property var wakeTimer: Timer {
            property double last: Date.now()
            interval: 30000; running: true; repeat: true
            onTriggered: {
                var now = Date.now()
                if (now - last > interval * 3) {
                    sharedSys.battProc.running = true
                    sharedSys.recordingProc.running = true
                    sharedSys.stats.refresh()
                    sharedSys.updateRecheck.restart()
                }
                last = now
            }
        }

        // CPU-temp warning — one toast for the machine, not one per monitor.
        property var tempTimer: Timer {
            interval: 10000; running: true; repeat: true
            onTriggered: {
                if (sharedSys.stats.cpuTemp >= 75 && !sharedSys.tempWarned) {
                    var msg = "CPU is " + Math.round(sharedSys.stats.cpuTemp) + "C"
                    pushNotification("Moonlit", "Temperature warning", msg)
                    if (!sys.dnd) toastRelay.notify("Moonlit", "Temperature warning", msg)
                    sharedSys.tempWarned = true
                } else if (sharedSys.stats.cpuTemp < 68) {
                    sharedSys.tempWarned = false
                }
            }
        }
    }

    QtObject {
        id: toastRelay
        signal notify(string app, string title, string body)
    }

    // Relay so external triggers (e.g. brightness keys via IPC) reach every screen's OSD
    QtObject {
        id: osdRelay
        signal fire(string kind, real value)
    }

    // `qs ipc call osd set brightness 50`  (don't name it `show` — collides with `qs ipc show`)
    IpcHandler {
        target: "osd"
        function set(kind: string, value: real): void {
            osdRelay.fire(kind, value)
        }
    }

    // `qs ipc call notify send Moonlit "Title" "Body"` for internal shell messages.
    IpcHandler {
        target: "notify"
        property int count: notifItems.length
        function send(app: string, title: string, body: string): void {
            pushNotification(app, title, body)
            if (!sys.dnd)
                toastRelay.notify(app, title, body)
        }
    }

    // Relay so a keybind can open/toggle a panel on every screen's scope
    QtObject {
        id: panelRelay
        signal toggle(string name)
    }

    // `qs ipc call panel toggle wallpaper`
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            panelRelay.toggle(name)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: QtObject {
            id: scope
            required property var modelData

            property string activePanel: ""
            property real   osdValue:   0
            property string osdKind:    ""
            property bool   osdVisible: false

            function open(p) { activePanel = (activePanel === p ? "" : p) }
            function closeAll() { activePanel = "" }
            function showOsd(kind, val) {
                osdKind = kind; osdValue = val; osdVisible = true
                osdTimer.restart()
            }

            property var osdTimer: Timer { interval: 1300; onTriggered: scope.osdVisible = false }

            property var osdRelayConn: Connections {
                target: osdRelay
                function onFire(kind, value) { scope.showOsd(kind, value) }
            }

            property var panelRelayConn: Connections {
                target: panelRelay
                // Open keybind-triggered panels (e.g. the wallpaper picker)
                // only on the monitor that currently has focus, so it shows
                // up where you're looking instead of on every screen.
                function onToggle(name) {
                    var fm = Hyprland.focusedMonitor
                    if (!fm || fm.name === scope.modelData.name) scope.open(name)
                }
            }

            // ── Bar ──────────────────────────────────────────────────────
            property var bar: Bar {
                screen:      scope.modelData
                shared:      sharedSys
                activePanel: scope.activePanel
                onOpenPanel: p  => scope.open(p)
                onShowOsd:  (k,v) => scope.showOsd(k, v)
                onShowToast: (a,t,b) => {
                    pushNotification(a, t, b)
                    toastRelay.notify(a, t, b)
                }
            }

            // Caffeine — inhibits compositor idle while enabled (attached to the
            // always-visible bar so it persists after the panel closes)
            property var idleInhibit: IdleInhibitor {
                window:  scope.bar
                enabled: sys.caffeine
            }

            // ── Click-outside catcher ────────────────────────────────────
            property var catcher: PanelWindow {
                screen: scope.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                margins.top: 42
                exclusiveZone: 0
                color: "transparent"
                visible: scope.activePanel !== "" &&
                         scope.activePanel !== "power" &&
                         scope.activePanel !== "wallpaper" &&
                         scope.activePanel !== "launcher" &&
                         scope.activePanel !== "overview"
                MouseArea { anchors.fill: parent; onClicked: scope.closeAll() }
            }

            // ── Panels ───────────────────────────────────────────────────
            property var calPanel: CalendarPanel {
                screen:        scope.modelData
                visible:       scope.activePanel === "cal"
                notifications: notifItems
                removeNotifFunc: removeNotification
                onClose:       scope.closeAll()
                onClearNotifs: {
                    var next = []
                    for (var i = 0; i < notifItems.length; i++) {
                        var item = {}
                        for (var key in notifItems[i])
                            item[key] = notifItems[i][key]
                        item.closing = true
                        next.push(item)
                    }
                    notifItems = next
                    for (var j = 0; j < notifModel.count; j++)
                        notifModel.setProperty(j, "closing", true)
                    clearNotifTimer.restart()
                }
                onDismissNotif: nid => setNotificationClosing(nid)
            }

            property var qsPanel: QuickSettingsPanel {
                screen:      scope.modelData
                visible:     scope.activePanel === "qs"
                onClose:     scope.closeAll()
                onShowOsd:  (k,v) => scope.showOsd(k, v)
                onOpenPanel: p    => scope.open(p)

                dndOn:        sys.dnd
                caffeineOn:   sys.caffeine
                nightOn:      sys.nightLight
                onToggleDnd:      sys.dnd        = !sys.dnd
                onToggleCaffeine: sys.caffeine   = !sys.caffeine
                onToggleNight:    sys.nightLight = !sys.nightLight
            }

            property var sysPanel: SysMonPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "sysmon"
                onClose: scope.closeAll()
            }

            property var wifiPanelWin: WifiPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "net"
                onClose: scope.closeAll()
            }

            property var btPanelWin: BtPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "bt"
                onClose: scope.closeAll()
            }

            property var audioPanel: AudioPanel {
                screen:      scope.modelData
                visible:     scope.activePanel === "audio"
                onClose:     scope.closeAll()
                onShowOsd:  (k,v) => scope.showOsd(k, v)
            }

            property var clipPanel: ClipPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "clip"
                onClose: scope.closeAll()
            }

            property var powerPanel: PowerPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "power"
                onClose: scope.closeAll()
            }

            property var wallpaperPanel: WallpaperPanel {
                screen:     scope.modelData
                outputName: scope.modelData.name   // apply only to this monitor
                visible:    scope.activePanel === "wallpaper"
                onClose:    scope.closeAll()
            }

            property var overviewPanel: WindowOverview {
                screen:  scope.modelData
                visible: scope.activePanel === "overview"
                onClose: scope.closeAll()
            }

            property var osdWin: OSD {
                screen:  scope.modelData
                visible: scope.osdVisible
                kind:    scope.osdKind
                value:   scope.osdValue
            }

            property var toastWin: ToastStack {
                screen: scope.modelData
                relay:  toastRelay
            }
        }
    }
}
