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
    // Bar edge: "top" (horizontal) | "left" | "right" (vertical side bar).
    readonly property string barPosition: adapter.barPosition
    // Bar look + per-widget visibility.
    readonly property real   barOpacity:    adapter.barOpacity
    readonly property bool   clock24h:       adapter.clock24h
    readonly property bool   showUpdates:    adapter.showUpdates
    readonly property bool   showTemp:       adapter.showTemp
    readonly property bool   showBattery:    adapter.showBattery
    readonly property bool   showRecording:  adapter.showRecording

    // ── Palette (Catppuccin flavor) ──────────────────────────────────────
    // flavor picks the neutral ramp (base…text); accent stays separate on top.
    readonly property string flavor: adapter.flavor

    readonly property var _flavors: ({
        "mocha":     { base:"#1e1e2e", mantle:"#181825", crust:"#11111b", surface0:"#313244", surface1:"#45475a", surface2:"#585b70", overlay0:"#6c7086", overlay1:"#7f849c", overlay2:"#9399b2", subtext0:"#a6adc8", subtext1:"#bac2de", text:"#cdd6f4" },
        "macchiato": { base:"#24273a", mantle:"#1e2030", crust:"#181926", surface0:"#363a4f", surface1:"#494d64", surface2:"#5b6078", overlay0:"#6e738d", overlay1:"#8087a2", overlay2:"#939ab7", subtext0:"#a5adcb", subtext1:"#b8c0e0", text:"#cad3f5" },
        "frappe":    { base:"#303446", mantle:"#292c3c", crust:"#232634", surface0:"#414559", surface1:"#51576d", surface2:"#626880", overlay0:"#737994", overlay1:"#838ba7", overlay2:"#949cbb", subtext0:"#a5adce", subtext1:"#b5bfe2", text:"#c6d0f5" },
        "latte":     { base:"#eff1f5", mantle:"#e6e9ef", crust:"#dce0e8", surface0:"#ccd0da", surface1:"#bcc0cc", surface2:"#acb0be", overlay0:"#9ca0b0", overlay1:"#8c8fa1", overlay2:"#7c7f93", subtext0:"#6c6f85", subtext1:"#5c5f77", text:"#4c4f69" }
    })
    readonly property var _p: _flavors[flavor] !== undefined ? _flavors[flavor] : _flavors["mocha"]

    readonly property color base:     _p.base
    readonly property color mantle:   _p.mantle
    readonly property color crust:    _p.crust
    readonly property color surface0: _p.surface0
    readonly property color surface1: _p.surface1
    readonly property color surface2: _p.surface2
    readonly property color overlay0: _p.overlay0
    readonly property color overlay1: _p.overlay1
    readonly property color overlay2: _p.overlay2
    readonly property color subtext0: _p.subtext0
    readonly property color subtext1: _p.subtext1
    readonly property color text:     _p.text

    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/moonlit/config.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#cba6f7"
            property string flavor: "mocha"
            property string barStyle: "islands"
            property string barPosition: "top"
            property real   barOpacity: 0.72
            property bool   clock24h: true
            property bool   showUpdates: true
            property bool   showTemp: true
            property bool   showBattery: true
            property bool   showRecording: true
        }
    }
}
