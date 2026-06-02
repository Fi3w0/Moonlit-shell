# Moonlit Shell — Full Package List

> Everything needed to make this rice work on a fresh Arch install.
> Matched against the live system. `[AUR]` = AUR.

---

## Core Desktop

```bash
sudo pacman -S \
  hyprland \
  hypridle \
  hyprlock \
  hyprsunset \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  sddm \
  qt6-wayland
```

## Shell / Bar / Panels

```bash
# [AUR] quickshell — bar + panels + IPC
yay -S quickshell
```

## Audio

```bash
sudo pacman -S \
  pipewire \
  wireplumber \
  pipewire-pulse \
  pipewire-alsa
```

## Network & Bluetooth

```bash
sudo pacman -S \
  networkmanager \
  network-manager-applet \
  bluez \
  bluez-utils

sudo systemctl enable NetworkManager bluetooth
```

## Wallpaper, Screenshots & Clipboard

```bash
# [AUR]
yay -S awww cliphist

sudo pacman -S \
  grim \
  slurp \
  wl-clipboard
```

## Terminal, Launcher & File Manager

```bash
sudo pacman -S \
  kitty \
  rofi \
  thunar \
  tumbler \
  ffmpegthumbnailer \
  gvfs \
  gnome-themes-extra \
  xdg-utils
```

## Shell & Editor

```bash
sudo pacman -S fish neovim git
```

## Fonts & Icons

```bash
sudo pacman -S ttf-jetbrains-mono-nerd papirus-icon-theme

# Cursor — included in this repo
cp -r .icons/Bibata-Modern-Classic ~/.icons/
```

## System Utilities

```bash
sudo pacman -S \
  brightnessctl \
  keyd \
  htop

# Enable keyd, then copy config
sudo systemctl enable --now keyd
sudo cp .config/keyd/default.conf /etc/keyd/default.conf && sudo keyd reload
```

## My Apps

```bash
sudo pacman -S firefox discord steam code

# [AUR]
yay -S spotify-launcher
```

## Media

```bash
sudo pacman -S mpv imv
```

## System Info & Monitoring

```bash
sudo pacman -S fastfetch

# [AUR]
yay -S dgop
```

## Ranger (File Manager)

```bash
sudo pacman -S ranger 7zip

# ranger_devicons plugin is bundled in this repo
```

## Archive & Download

```bash
sudo pacman -S 7zip zip wget
```

## Networking extras

```bash
sudo pacman -S openssh
```

## Optional (config references but not required)

```bash
# CPU temp in bar — sensors command
sudo pacman -S lm_sensors

# Airplane mode toggle — rfkill command
sudo pacman -S rfkill

# Battery info in SysMon panel
sudo pacman -S upower

# Ranger image previews
sudo pacman -S w3m python-pillow

# Archive handling in ranger
sudo pacman -S atool p7zip unrar unzip

# Fish aliases (mc = docker, ai = ollama)
sudo pacman -S docker
# ollama — curl -fsSL https://ollama.com/install.sh | sh
# spicetify — curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
```

---

## Quick Install

```bash
# Pacman — everything essential
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  sddm qt6-wayland \
  pipewire wireplumber pipewire-pulse pipewire-alsa \
  networkmanager network-manager-applet bluez bluez-utils \
  grim slurp wl-clipboard kitty rofi thunar tumbler \
  ffmpegthumbnailer gvfs gnome-themes-extra xdg-utils \
  fish neovim git ttf-jetbrains-mono-nerd papirus-icon-theme \
  brightnessctl keyd htop mpv imv \
  firefox discord steam code fastfetch ranger 7zip \
  zip wget openssh

# AUR
yay -S quickshell awww cliphist spotify-launcher dgop

# Enable services
sudo systemctl enable NetworkManager bluetooth sddm keyd
```

## Deploy Dots

```bash
# Dotfiles
cp -r .config/* ~/.config/
cp -r .icons/Bibata-Modern-Classic ~/.icons/
cp -r Wallpapers/ ~/Pictures/Wallpapers/

# SDDM — install theme + config + wallpaper
sudo cp -r sddm/catppuccin-mocha /usr/share/sddm/themes/
sudo cp sddm/sddm.conf /etc/sddm.conf
sudo ln -sf "$(cat ~/.cache/wallpaper-current)" /usr/share/sddm/themes/catppuccin-mocha/backgrounds/wall.jpg

# GTK — install theme (from GitHub releases)
mkdir -p ~/.themes ~/.config/gtk-3.0 ~/.config/gtk-4.0
curl -sL "https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-lavender-standard%2Bdefault.zip" -o /tmp/catppuccin-gtk.zip
unzip -o /tmp/catppuccin-gtk.zip -d ~/.themes/

# GTK settings are already in .config/gtk-3.0/ and .config/gtk-4.0/

# keyd
sudo cp .config/keyd/default.conf /etc/keyd/default.conf && sudo keyd reload

# Neovim
nvim --headless "+Lazy! sync" +qa
```
