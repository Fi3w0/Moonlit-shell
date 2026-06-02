# Moonlit Shell — Full Package List

> Everything needed to make this rice work on a fresh Arch install.
> Lines marked `[AUR]` come from the AUR.
> Lines marked `[manual]` are manual installs (git clone / copy).

---

## Core Desktop

```bash
sudo pacman -S \
  hyprland \
  hypridle \
  hyprlock \
  hyprsunset \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk
```

## Shell / Bar / Panels

```bash
# quickshell — the bar, panels, and IPC system
# [AUR] — yay -S quickshell
# or build from source: https://gitlab.com/quickshell/quickshell
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
# awww — animated wallpaper daemon
# [AUR] — yay -S awww
yay -S awww

sudo pacman -S \
  grim \
  slurp \
  wl-clipboard

# cliphist — clipboard history (part of wl-clipboard on some distros)
# [AUR] if not bundled — yay -S cliphist
yay -S cliphist
```

## Terminal, Launcher & File Manager

```bash
sudo pacman -S \
  kitty \
  rofi \
  thunar \
  tumbler \
  xdg-utils
```

## Shell & Editor

```bash
sudo pacman -S \
  fish \
  neovim \
  git
```

## Fonts & Icons

```bash
sudo pacman -S \
  ttf-jetbrains-mono-nerd \
  papirus-icon-theme
```

### Cursor Theme

```bash
# Bibata-Modern-Classic is included in this repo under .icons/
# Copy it to your system:
cp -r .icons/Bibata-Modern-Classic ~/.icons/
```

## System Utilities

```bash
sudo pacman -S \
  brightnessctl \
  upower \
  lm_sensors \
  rfkill \
  procps-ng \
  coreutils \
  findutils \
  gawk \
  sed \
  util-linux \
  keyd

# Enable keyd
sudo systemctl enable --now keyd
# Then copy keyd config: cp .config/keyd/default.conf /etc/keyd/default.conf && sudo keyd reload
```

## My Apps

```bash
sudo pacman -S \
  firefox \
  discord

# [AUR] — spotify-launcher
yay -S spotify-launcher

sudo pacman -S \
  steam \
  code
```

## System Info & Monitoring

```bash
sudo pacman -S fastfetch

# dgop — system monitor
# [AUR] — yay -S dgop
yay -S dgop
```

## Ranger (File Manager)

```bash
sudo pacman -S \
  ranger \
  w3m \
  python-pillow \
  file \
  atool \
  p7zip \
  unrar \
  unzip

# ranger_devicons plugin is included in this repo already
# (git clone https://github.com/alexanderjeurissen/ranger_devicons ~/.config/ranger/plugins/ranger_devicons)
```

## Optional / Extra

```bash
# Minecraft server alias in fish
sudo pacman -S docker

# AI via ollama
# [manual] — curl -fsSL https://ollama.com/install.sh | sh
# or yay -S ollama

# Spotify customization
# [manual] — curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
```

---

## Quick Install (copy-paste)

```bash
# Core + Utils
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  pipewire wireplumber pipewire-pulse pipewire-alsa \
  networkmanager network-manager-applet bluez bluez-utils \
  grim slurp wl-clipboard kitty rofi thunar tumbler xdg-utils \
  fish neovim git ttf-jetbrains-mono-nerd papirus-icon-theme \
  brightnessctl upower lm_sensors rfkill keyd \
  firefox discord steam code fastfetch \
  ranger w3m python-pillow file atool p7zip unrar unzip docker \
  procps-ng coreutils findutils gawk sed util-linux

# AUR
yay -S quickshell awww cliphist spotify-launcher dgop

# Enable services
sudo systemctl enable --now NetworkManager bluetooth keyd
```

## Deploy Dots

```bash
# Copy everything from this repo to ~/.config/
cp -r .config/* ~/.config/
cp -r .icons/Bibata-Modern-Classic ~/.icons/
cp -r Wallpapers/ ~/Pictures/Wallpapers/

# keyd config (as root)
sudo cp .config/keyd/default.conf /etc/keyd/default.conf
sudo keyd reload

# Setup nvim plugins (first launch auto-installs lazy.nvim)
nvim --headless "+Lazy! sync" +qa
```
