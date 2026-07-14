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

    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/moonlit/config.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#cba6f7"
        }
    }
}
