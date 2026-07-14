pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for Moonlit Shell.
// The moonlit-settings app writes ~/.config/moonlit/config.json; this
// singleton live-reads it (watchChanges) so the shell restyles instantly.
// Everything the shell should let users tweak lives here — never hardcode
// a themeable value in a panel again; bind to Config.<key> instead.
Singleton {
    id: root

    // Moonlight mauve accent — drives active/hover states across the shell.
    readonly property color accent: adapter.accent
    // Top bar layout: "islands" (floating pills) or "classic" (solid topbar).
    readonly property string barStyle: adapter.barStyle
    // Bar look + per-widget visibility.
    readonly property real   barOpacity:    adapter.barOpacity
    readonly property bool   clock24h:       adapter.clock24h
    readonly property bool   showUpdates:    adapter.showUpdates
    readonly property bool   showTemp:       adapter.showTemp
    readonly property bool   showBattery:    adapter.showBattery
    readonly property bool   showRecording:  adapter.showRecording

    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/moonlit/config.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#cba6f7"
            property string barStyle: "islands"
            property real   barOpacity: 0.72
            property bool   clock24h: true
            property bool   showUpdates: true
            property bool   showTemp: true
            property bool   showBattery: true
            property bool   showRecording: true
        }
    }
}
