<div align="center">

# 🌙 Moonlit Shell

**A handcrafted Arch Linux desktop, built on Hyprland and a custom Quickshell interface.**

<br>

[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-89b4fa?style=for-the-badge&logo=archlinux&logoColor=1e1e2e)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-cba6f7?style=for-the-badge&logo=hyprland&logoColor=1e1e2e)](https://hyprland.org)
[![Wayland](https://img.shields.io/badge/Wayland-89dceb?style=for-the-badge&logo=wayland&logoColor=1e1e2e)](https://wayland.freedesktop.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-a6e3a1?style=for-the-badge&logo=qt&logoColor=1e1e2e)](https://quickshell.outfoxxed.me)

[![Catppuccin Mocha](https://img.shields.io/badge/Catppuccin%20Mocha-f5c2e7?style=for-the-badge&logo=catppuccin&logoColor=1e1e2e)](https://catppuccin.com)
[![License GPLv3](https://img.shields.io/badge/License-GPLv3-f9e2af?style=for-the-badge&logoColor=1e1e2e)](LICENSE)
[![Status](https://img.shields.io/badge/status-experimental-fab387?style=for-the-badge)](#status--roadmap)

<br>

<img src="assets/screenshots/mainscreen.png" alt="Moonlit Shell" width="850"/>

</div>

---

## Overview

Moonlit Shell is a complete, cohesive desktop rather than a pile of glued-together scripts. The bar and every panel are written like a real application in Quickshell (a Qt6/QML shell framework) and talk to the system over IPC, so nothing races and nothing breaks in surprising ways. From the SDDM login to the lock screen to the wallpaper carousel, every surface is soaked in Catppuccin Mocha and tuned for a calm, nocturnal workflow.

It is my daily driver on a ThinkPad T14, rebuilt from the ground up after my old Waybar setup kept hitting walls: no proper WiFi dialog, no Bluetooth pairing UI, no clipboard history, no wallpaper picker. Quickshell let me solve all of that properly, once.

---

## Highlights

- **Custom Quickshell bar** with workspaces, window title, a styled system tray, and live stats read straight from `/proc` and `sysfs`, no external daemon.
- **Twelve real panels**, including full WiFi connect, Bluetooth pairing, clipboard history, an audio/MPRIS hub, a system monitor, and a wallpaper carousel.
- **Frosted glass everywhere**, Hyprland blur flowing through the bar, panels, Thunar, and Hyprlock over your live wallpaper.
- **One coherent theme**, Catppuccin Mocha applied across Hyprland, Kitty, Rofi, Fish, Neovim, Ranger, Fastfetch, dgop, GTK, and the SDDM login screen.
- **Wallpaper carousel** with momentum scrolling, applied instantly via `awww` and remembered across reboots.
- **Automated installer** with Minimal, Developer, and Full presets (see [Installation](#installation)).

---

## Gallery

<p align="center">
  <img src="assets/screenshots/rofi+hardware.png" alt="Rofi + Fastfetch" width="850"/>
  <br><i>Rofi launcher and live hardware system info</i>
</p>

<p align="center">
  <img src="assets/screenshots/settings+soundbar.png" alt="Quick Settings + Audio" width="850"/>
  <br><i>Quick settings panel with volume and brightness sliders</i>
</p>

<p align="center">
  <img src="assets/screenshots/powermenu.png" alt="Power Menu" width="850"/>
  <br><i>Power menu with Lock, Logout, Sleep, Reboot, Shutdown</i>
</p>

<p align="center">
  <img src="assets/screenshots/wallpaperselector.png" alt="Wallpaper Picker" width="850"/>
  <br><i>Wallpaper carousel with momentum scrolling</i>
</p>

<p align="center">
  <img src="assets/screenshots/lockscreen.png" alt="Lock Screen" width="850"/>
  <br><i>Hyprlock with frosted glass blur over the current wallpaper</i>
</p>

---

## The Bar &amp; Panels

A Quickshell bar that is more functional than most full desktop environments I have used.

| Panel | What it does |
|-------|--------------|
| **Quick Settings** | Toggles for WiFi, Bluetooth, DND, Night Light, Caffeine, and Airplane mode, plus volume and brightness sliders with live OSD |
| **Audio** | MPRIS now-playing with seek bar, play/pause/skip, master volume, and mic level |
| **WiFi** | Scan nearby networks, connect with a password dialog, signal strength bars |
| **Bluetooth** | Paired device list, scan, connect/disconnect, power toggle |
| **Power** | Lock, Logout, Sleep, Reboot, Shutdown with keyboard shortcuts |
| **System Monitor** | CPU sparkline, RAM/Disk/Temp ring charts, network throughput, top processes |
| **Calendar** | Full month grid, live clock, now-playing widget, notification history |
| **Clipboard** | `cliphist` history with copy-to-clipboard and clear |
| **Wallpaper Picker** | Circular carousel with momentum scrolling, click to apply via `awww` |
| **OSD** | Volume and brightness popups triggered by any source (keys, sliders, scripts) |

The bar itself shows workspaces (a pill for the active one, a dot for occupied), the current window title, a system tray with styled context menus, and real-time stats.

---

## Tech Stack

| Layer | Tool |
|-------|------|
| Compositor | Hyprland 0.55 |
| Bar / Shell | Quickshell (QML) |
| Launcher | Rofi |
| Terminal | Kitty |
| Editor | Neovim (lazy.nvim) |
| File Manager | Thunar and Ranger |
| Lock Screen | Hyprlock (frosted glass, live wallpaper) |
| Login | SDDM (catppuccin-mocha-mauve) |
| Audio | PipeWire and WirePlumber |
| Theme | Catppuccin Mocha |
| Font | JetBrainsMono Nerd Font Mono |
| Icons | Papirus-Dark |
| Cursor | Bibata-Modern-Classic |

---

## Keybinds

| Key | Action |
|-----|--------|
| `SUPER` + `Q` | Kitty |
| `SUPER` + `Space` | Rofi launcher |
| `SUPER` + `B` | Wallpaper picker |
| `SUPER` + `Shift` + `B` | Random wallpaper |
| `SUPER` + `1`–`4` | Switch workspace |
| `SUPER` + `F` | Fullscreen |
| `SUPER` + `W` | Close window |
| `SUPER` + `Tab` | Cycle windows |
| `SUPER` + `P` | Toggle float |
| `ALT` + `S` | Screenshot region to clipboard |
| `ALT` + `D` | Screenshot full to clipboard |

---

## Installation

> **AMD / Intel GPUs only** for now. NVIDIA is not tested with these dots.

### Automated (experimental)

An installer handles packages, services, themes, and dotfiles for you:

```bash
git clone https://github.com/Fi3w0/Moonlit-shell.git
cd Moonlit-shell
./install.sh            # pick a tier; add --progress for a progress-bar UI
```

It asks for `sudo` up front, shows the full package and action list to confirm before touching anything, backs up any configs it overwrites, and logs every command to `~/.cache/moonlit/install-*.log`. Pick a tier:

| Tier | What you get |
|------|--------------|
| **Minimal** | Hyprland and Quickshell desktop, all sensors, SDDM (no theme) |
| **Developer** | Minimal plus VS Code, Neovim config, Ranger, dgop |
| **Full** ★ | Everything plus the Catppuccin SDDM theme and Discord/Steam/Spotify |

### Manual

Prefer to do it by hand, or running NVIDIA? It is not a copy-paste job, so read the guide.

> **[MANUAL-INSTALL.md](MANUAL-INSTALL.md)**

These configs assume a single laptop display (ThinkPad T14, 1920x1080, 1x scale), PipeWire audio, and NetworkManager. Adjust monitors, interface names, and paths before applying.

---

## Project Layout

```
.config/
├── hypr/              Hyprland: split configs, gradient borders, frosted blur
│   └── scripts/
│       └── lock.sh    Hyprlock wrapper (reads current wallpaper for blur)
├── quickshell/        The bar and 12 panels
│   ├── bar/           Workspaces, tray, stats, clock
│   └── panels/        QS, audio, wifi, bt, power, calendar,
│                      sysmon, clipboard, wallpaper picker, OSD, toasts
├── kitty/             Terminal: catppuccin palette, 42% opacity
├── rofi/              Launcher with pinned apps, quicklinks, file search
├── fish/              Shell: frozen theme, aliases
├── nvim/              Editor: catppuccin, lazy.nvim
├── ranger/            File manager: miller columns, devicons, catppuccin
├── fastfetch/         System info
├── dgop/              System monitor
├── Thunar/            File manager actions and keybinds
├── keyd/              Keyboard remapping (meta layer)
├── gtk-3.0/           GTK theming
└── gtk-4.0/           GTK theming
```

A few behaviors worth knowing:

- The bar polls `/proc` and `sysfs` directly, with no external monitoring daemon.
- Caffeine mode inhibits idle so there is no accidental suspend during presentations or long downloads.
- Night Light toggles `hyprsunset -t 4500` for warm color at night.
- Airplane mode calls `rfkill block all`, so make sure `rfkill` is installed if you use it.

---

## Status &amp; Roadmap

Moonlit Shell is in active development. **Expect bugs, expect rough edges, and use at your own risk.** It is not a finished product yet.

Planned for the road ahead:

- More installer presets (minimal / max / dev / gaming) so everyone can land on a setup they enjoy.
- A showcase video of the desktop in motion.
- Custom and further-themed apps.
- Bug fixes and ongoing updates to track new Arch and Hyprland releases.

---

## License

Released under the [GPLv3](LICENSE). Explore it, fork it, break things, and make it yours.

<div align="center">
<br>
<sub>These are my dots, tailored to my workflow. Steal what you like, adapt the rest. That is how I learned too. 🌙</sub>
</div>
