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
                         scope.activePanel !== "launcher"
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
