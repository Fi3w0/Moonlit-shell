# Moonlit Shell — Manual Install Guide

> Fresh Arch Linux → fully riced desktop. Follow steps 1–7 in order.

---

## 1. Prerequisites

```bash
# You need an AUR helper. If you don't have one:
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
```

---

## 2. Install Packages

### 2.1 Core Desktop (pacman)

```bash
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  sddm qt6-wayland
```

### 2.2 Bar & Shell

```bash
yay -S quickshell
```

### 2.3 Audio

```bash
sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-alsa
```

### 2.4 Network & Bluetooth

```bash
sudo pacman -S networkmanager network-manager-applet bluez bluez-utils
```

### 2.5 Wallpaper, Screenshots & Clipboard

```bash
yay -S awww cliphist
sudo pacman -S grim slurp wl-clipboard
```

### 2.6 Terminal, Launcher & File Manager

```bash
sudo pacman -S \
  kitty rofi thunar tumbler ffmpegthumbnailer \
  gvfs gnome-themes-extra xdg-utils
```

### 2.7 Shell & Editor

```bash
sudo pacman -S fish neovim git
```

### 2.8 Fonts & Icons

```bash
sudo pacman -S ttf-jetbrains-mono-nerd papirus-icon-theme
```

### 2.9 System Utilities

```bash
sudo pacman -S brightnessctl keyd htop
```

### 2.10 Apps & Media

```bash
sudo pacman -S firefox discord steam code mpv imv

yay -S spotify-launcher
```

### 2.11 System Info

```bash
sudo pacman -S fastfetch

yay -S dgop
```

### 2.12 File Manager & Archive Tools

```bash
sudo pacman -S ranger 7zip zip wget

# ranger_devicons plugin is bundled in this repo — no extra install needed
```

### 2.13 Networking Extras

```bash
sudo pacman -S openssh
```

### 2.14 Optional (improves functionality)

```bash
# CPU temp in bar
sudo pacman -S lm_sensors

# Airplane mode toggle in quick settings
sudo pacman -S rfkill

# Battery stats in system monitor panel
sudo pacman -S upower

# Ranger image previews
sudo pacman -S w3m python-pillow

# Ranger archive handling
sudo pacman -S atool p7zip unrar unzip

# Fish aliases
sudo pacman -S docker
# ollama AI → curl -fsSL https://ollama.com/install.sh | sh
# spicetify  → curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
```

---

## 3. Enable Services

```bash
sudo systemctl enable --now NetworkManager bluetooth
sudo systemctl enable --now keyd
sudo systemctl enable sddm
```

---

## 4. Install Themes

### 4.1 SDDM

```bash
# Catppuccin Mocha Mauve login screen (QML theme)
git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm
sudo cp -r /tmp/catppuccin-sddm/src /usr/share/sddm/themes/catppuccin-mocha-mauve

# Drop-in config — sets theme without touching the existing SDDM config
sudo cp sddm/sddm.conf /etc/sddm.conf.d/10-theme.conf

# Background — copy a wallpaper so the SDDM user can read it (no symlinks!)
sudo cp "$(cat ~/.cache/wallpaper-current 2>/dev/null || echo '/usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/wall.png')" \
  /usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/wall.png
```

### 4.2 GTK

```bash
mkdir -p ~/.themes

curl -sL \
  "https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-lavender-standard%2Bdefault.zip" \
  -o /tmp/catppuccin-gtk.zip
7z x -y /tmp/catppuccin-gtk.zip -o~/.themes/

# Settings are included in the dotfiles in .config/gtk-3.0/ and .config/gtk-4.0/
```

### 4.3 Cursor Theme

```bash
cp -r .icons/Bibata-Modern-Classic ~/.icons/
```

---

## 5. Deploy Dotfiles

```bash
# All configs
cp -r .config/* ~/.config/

# Wallpapers
cp -r Wallpapers/ ~/Pictures/Wallpapers/

# keyd — requires reload after copying
sudo cp .config/keyd/default.conf /etc/keyd/default.conf
sudo keyd reload
```

---

## 6. Post-Install

```bash
# Set wallpaper for the first time (avoids hyprlock failing on a missing cache)
awww img ~/Pictures/Wallpapers/wallpaper4.jpg -t none
echo ~/Pictures/Wallpapers/wallpaper4.jpg > ~/.cache/wallpaper-current

# Install neovim plugins
nvim --headless "+Lazy! sync" +qa

# Make the lock script executable
chmod +x ~/.config/hypr/scripts/lock.sh
```

---

## 7. Reboot & Verify

```bash
systemctl reboot
```

**What should work after reboot:**

| Component | What to check |
|-----------|---------------|
| SDDM | Catppuccin login screen with your wallpaper |
| Hyprland | Gradient borders, frosted blur, workspace animations |
| Quickshell | Top bar with workspaces, stats, tray, clock |
| Keybinds | `SUPER+Space` (rofi), `SUPER+B` (wallpaper picker), `SUPER+Q` (kitty) |
| Panels | Click clock → calendar, settings gear → quick settings, power → power menu |
| Hyprlock | `SUPER+Ctrl+L` or idle — wallpaper with frosted glass |
| Rofi | Catppuccin themed app launcher + quicklinks (`>`) + file search (`!`) |
| Thunar | Frosted semi-transparent, catppuccin GTK theme |
| Kitty | 42% opacity, catppuccin palette |
| Ranger | Miller columns + devicons + catppuccin colors |
| Fish | Frozen theme, mc/ai/openco aliases |
| Neovim | Catppuccin transparent background, purple highlights |
