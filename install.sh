#!/usr/bin/env bash
# ╭───────────────────────────────────────────────────────────────╮
# │  Moonlit Shell - automated installer                          │
# │  Tiers: minimal · dev · full      GPU: AMD / Intel only        │
# ╰───────────────────────────────────────────────────────────────╯
#
#  EXPERIMENTAL - this installer is young and may not work perfectly
#  on every machine. It logs everything; if a step breaks, read the
#  log it prints at the end and you can finish from MANUAL-INSTALL.md.
#
#  Usage:
#    ./install.sh                 spinner UI, pick tier interactively
#    ./install.sh --progress      progress-bar UI instead of spinner
#    ./install.sh --full          skip the menu, install the Full tier
#    ./install.sh --minimal|--dev likewise
#    ./install.sh --help
#
#  Display style can also be set with  MOONLIT_STYLE=bar ./install.sh
#
set -uo pipefail

# ── locate repo ───────────────────────────────────────────────────
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO" || { echo "cannot cd to repo"; exit 1; }

# ── log file ──────────────────────────────────────────────────────
LOGDIR="${XDG_CACHE_HOME:-$HOME/.cache}/moonlit"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/install-$(date +%Y%m%d-%H%M%S).log"
: >"$LOG"
log()  { printf '%s\n' "$*" >>"$LOG"; }
logh() { printf '\n=== %s ===\n' "$*" >>"$LOG"; }

# ── colours (catppuccin mocha) ────────────────────────────────────
if [[ -t 1 ]]; then
  R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'
  MAUVE=$'\e[38;2;203;166;247m'; GREEN=$'\e[38;2;166;227;161m'
  YELLOW=$'\e[38;2;249;226;175m'; RED=$'\e[38;2;243;139;168m'
  BLUE=$'\e[38;2;137;180;250m';  SKY=$'\e[38;2;137;220;235m'
  GREY=$'\e[38;2;108;112;134m';  LAV=$'\e[38;2;180;190;254m'
else
  R= B= DIM= MAUVE= GREEN= YELLOW= RED= BLUE= SKY= GREY= LAV=
fi

info() { printf '%s %s\n'  "${BLUE}::${R}" "$*"; }
ok()   { printf '%s %s\n'  "${GREEN}✓${R}" "$*"; }
warn() { printf '%s %s\n'  "${YELLOW}!${R}" "$*" >&2; log "WARN: $*"; }
err()  { printf '%s %s\n'  "${RED}✗${R}" "$*" >&2; log "ERROR: $*"; }
die()  { err "$*"; err "Log: $LOG"; exit 1; }

# moon-phase animation frames
MOON=( "🌑" "🌒" "🌓" "🌔" "🌕" "🌖" "🌗" "🌘" )

cleanup() { tput cnorm 2>/dev/null; [[ -n "${KEEPALIVE_PID:-}" ]] && kill "$KEEPALIVE_PID" 2>/dev/null; }
trap cleanup EXIT
trap 'echo; err "Interrupted."; exit 130' INT

# ── args ──────────────────────────────────────────────────────────
STYLE="${MOONLIT_STYLE:-spin}"
TIER=""
ASSUME_YES=0
usage() { awk 'NR==1{next} /^[^#]/{exit} {sub(/^# ?/,""); print}' "$0"; }
for a in "$@"; do
  case "$a" in
    -p|--progress|--bar) STYLE=bar ;;
    --spin|--spinner)    STYLE=spin ;;
    --minimal) TIER=minimal ;;
    --dev)     TIER=dev ;;
    --full)    TIER=full ;;
    -y|--yes)  ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $a" ;;
  esac
done

# ══════════════════════════════════════════════════════════════════
#  PACKAGE / CONFIG SETS
# ══════════════════════════════════════════════════════════════════
# Minimal: a working Hyprland + Quickshell desktop, all sensors, SDDM
# (login manager) but with NO custom SDDM theme.
PAC_MINIMAL=(
  hyprland hypridle hyprlock hyprsunset
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6-wayland
  sddm
  pipewire wireplumber pipewire-pulse pipewire-alsa
  networkmanager network-manager-applet bluez bluez-utils
  grim slurp wl-clipboard
  kitty rofi thunar tumbler ffmpegthumbnailer gvfs gnome-themes-extra xdg-utils
  fish neovim git
  ttf-jetbrains-mono-nerd papirus-icon-theme
  brightnessctl keyd htop
  lm_sensors rfkill upower
  firefox mpv imv
  fastfetch
  unzip wget
)
AUR_MINIMAL=( quickshell awww cliphist )
CFG_MINIMAL=( hypr quickshell kitty rofi fish gtk-3.0 gtk-4.0 Thunar fastfetch keyd )

# Dev: minimal + developer tooling
PAC_DEV=( code ranger w3m python-pillow atool p7zip 7zip unrar zip openssh docker )
AUR_DEV=( dgop )
CFG_DEV=( nvim ranger dgop )

# Full: dev + chat/games/media + Catppuccin SDDM theme (configs = everything)
PAC_FULL=( discord steam )
AUR_FULL=( spotify-launcher )

# ══════════════════════════════════════════════════════════════════
#  BANNER
# ══════════════════════════════════════════════════════════════════
banner() {
  printf '\n'
  printf '   %s🌙%s %s────────────────────────────────────%s\n' "$YELLOW" "$R" "$MAUVE" "$R"
  printf '      %s%sM O O N L I T   S H E L L%s\n' "$B" "$MAUVE" "$R"
  printf '      %sHyprland · Quickshell · Catppuccin Mocha%s\n' "$GREY" "$R"
  printf '   %s────────────────────────────────────%s %s🌒%s\n' "$MAUVE" "$R" "$SKY" "$R"
  printf '\n'
  printf '   %s⚠ experimental%s - may not work on every setup; everything\n' "$YELLOW" "$R"
  printf '   is logged so you can recover from %sMANUAL-INSTALL.md%s if needed.\n\n' "$DIM" "$R"
}

# ══════════════════════════════════════════════════════════════════
#  PRE-FLIGHT
# ══════════════════════════════════════════════════════════════════
preflight() {
  # not root
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    die "Run this as your normal user, not root (it will call sudo when needed)."
  fi
  # arch-ish
  command -v pacman >/dev/null || die "pacman not found - this installer targets Arch Linux."

  # GPU guard: AMD / Intel only
  local gpu=""
  if command -v lspci >/dev/null; then
    gpu="$(lspci 2>/dev/null | grep -Ei 'vga|3d controller|display')"
  fi
  log "GPU: $gpu"
  if grep -qi nvidia <<<"$gpu"; then
    if grep -Eqi 'amd|ati|intel' <<<"$gpu"; then
      warn "NVIDIA GPU detected alongside AMD/Intel. These dots are tuned for AMD/Intel;"
      warn "the NVIDIA card may need nvidia-dkms + Hyprland env tweaks not handled here."
    else
      err "NVIDIA-only GPU detected. This installer currently supports AMD / Intel only."
      err "Hyprland on NVIDIA needs nvidia-dkms and extra env vars not configured here."
      if [[ $ASSUME_YES -eq 0 ]]; then
        read -rp "$(printf '%sContinue anyway at your own risk?%s [y/N] ' "$YELLOW" "$R")" a
        [[ "${a,,}" == y* ]] || die "Stopped (NVIDIA unsupported)."
      fi
    fi
  fi
}

# ── sudo: ask up-front, keep alive, stop if it fails ──────────────
get_sudo() {
  info "Moonlit needs ${B}sudo${R} to install packages and enable services."
  if ! sudo -v; then
    die "Sudo authentication failed or was cancelled. Stopping."
  fi
  # keepalive so backgrounded steps never block on a password prompt
  ( while true; do sudo -n true 2>/dev/null; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
  KEEPALIVE_PID=$!
  ok "sudo authorised"
}

# ══════════════════════════════════════════════════════════════════
#  TIER MENU (arrow keys, recommends Full)
# ══════════════════════════════════════════════════════════════════
choose_tier() {
  [[ -n "$TIER" ]] && return
  local opts=("Minimal" "Developer" "Full")
  local tags=("" "" "  ${YELLOW}★ recommended${R}")
  local subs=(
    "Hyprland + Quickshell desktop · all sensors · SDDM (no theme)"
    "Minimal + VS Code · Neovim config · Ranger · dgop"
    "Everything + Catppuccin SDDM theme + Discord/Steam/Spotify"
  )
  local n=${#opts[@]} sel=2   # default highlight = Full

  if [[ ! -t 0 || ! -t 1 ]]; then
    info "No TTY - defaulting to Full tier."
    TIER=full; return
  fi

  printf '   %sChoose an install tier%s  %s(↑/↓ or 1-3, Enter to confirm, q to quit)%s\n\n' \
    "$B$LAV" "$R" "$GREY" "$R"
  tput civis 2>/dev/null
  local first=1
  while true; do
    [[ $first -eq 0 ]] && printf '\e[%dA' $((n*2))
    first=0
    local i
    for ((i=0; i<n; i++)); do
      if [[ $i -eq $sel ]]; then
        printf '\r\e[K   %s❯ %s%s%s%s\n' "$MAUVE" "$B$MAUVE" "${opts[$i]}" "$R" "${tags[$i]}"
        printf '\r\e[K       %s%s%s\n' "$LAV" "${subs[$i]}" "$R"
      else
        printf '\r\e[K     %s%s%s%s\n' "$GREY" "${opts[$i]}" "$R" "${tags[$i]}"
        printf '\r\e[K\n'
      fi
    done
    IFS= read -rsn1 key
    [[ "$key" == $'\e' ]] && { read -rsn2 -t 0.01 k2; key+="$k2"; }
    case "$key" in
      $'\e[A'|k|K) ((sel>0)) && ((sel--)) || sel=$((n-1)) ;;
      $'\e[B'|j|J) ((sel<n-1)) && ((sel++)) || sel=0 ;;
      1) sel=0; break ;;
      2) sel=1; break ;;
      3) sel=2; break ;;
      ''|$'\n'|$'\r') break ;;
      q|Q) tput cnorm 2>/dev/null; echo; die "Cancelled." ;;
    esac
  done
  tput cnorm 2>/dev/null
  case $sel in 0) TIER=minimal ;; 1) TIER=dev ;; 2) TIER=full ;; esac
  printf '\n'
}

# ── build the effective package/config sets for the chosen tier ───
build_sets() {
  PAC=( "${PAC_MINIMAL[@]}" )
  AUR=( "${AUR_MINIMAL[@]}" )
  CFG=( "${CFG_MINIMAL[@]}" )
  SDDM_THEME=0; NVIM_SYNC=0; MULTILIB=0

  case "$TIER" in
    dev)
      PAC+=( "${PAC_DEV[@]}" ); AUR+=( "${AUR_DEV[@]}" ); CFG+=( "${CFG_DEV[@]}" )
      NVIM_SYNC=1
      ;;
    full)
      PAC+=( "${PAC_DEV[@]}" "${PAC_FULL[@]}" )
      AUR+=( "${AUR_DEV[@]}" "${AUR_FULL[@]}" )
      NVIM_SYNC=1; SDDM_THEME=1; MULTILIB=1
      # full deploys EVERY config directory in the repo
      CFG=()
      local d
      for d in .config/*/; do CFG+=( "$(basename "$d")" ); done
      ;;
  esac

  # phase count for the progress bar
  PHASE_TOTAL=7
  [[ $MULTILIB -eq 1 ]] && PHASE_TOTAL=8
}

# ── show exactly what will happen, then confirm ───────────────────
summary() {
  printf '%s╭─ Install plan ─ %s%s%s tier %s───────────────────────────%s\n' \
    "$MAUVE" "$B$MAUVE" "${TIER^}" "$R$MAUVE" "" "$R"
  printf '%s│%s\n' "$MAUVE" "$R"
  printf '%s│%s %spacman (%d):%s %s\n'  "$MAUVE" "$R" "$B$GREEN" "${#PAC[@]}" "$R" "$(fmt_list "${PAC[@]}")"
  printf '%s│%s\n' "$MAUVE" "$R"
  printf '%s│%s %sAUR (%d):%s %s\n'     "$MAUVE" "$R" "$B$SKY" "${#AUR[@]}" "$R" "$(fmt_list "${AUR[@]}")"
  printf '%s│%s\n' "$MAUVE" "$R"
  printf '%s│%s %sconfigs (%d):%s %s\n' "$MAUVE" "$R" "$B$LAV" "${#CFG[@]}" "$R" "$(fmt_list "${CFG[@]}")"
  printf '%s│%s\n' "$MAUVE" "$R"
  printf '%s│%s %sactions:%s\n' "$MAUVE" "$R" "$B$YELLOW" "$R"
  printf '%s│%s   • install/ensure yay (AUR helper)\n' "$MAUVE" "$R"
  [[ $MULTILIB -eq 1 ]]   && printf '%s│%s   • enable [multilib] repo (for Steam)\n' "$MAUVE" "$R"
  printf '%s│%s   • enable services: NetworkManager · bluetooth · keyd · sddm\n' "$MAUVE" "$R"
  printf '%s│%s   • deploy configs (existing ones backed up first)\n' "$MAUVE" "$R"
  printf '%s│%s   • GTK + Bibata cursor theme\n' "$MAUVE" "$R"
  [[ $SDDM_THEME -eq 1 ]] && printf '%s│%s   • Catppuccin Mocha SDDM theme\n' "$MAUVE" "$R"
  printf '%s│%s   • copy wallpapers → ~/Pictures/Wallpapers\n' "$MAUVE" "$R"
  [[ $NVIM_SYNC -eq 1 ]]  && printf '%s│%s   • sync Neovim plugins (lazy.nvim)\n' "$MAUVE" "$R"
  printf '%s│%s   • fix hardcoded paths · seed wallpaper cache · chmod lock script\n' "$MAUVE" "$R"
  printf '%s│%s\n' "$MAUVE" "$R"
  printf '%s│%s %sUI:%s %s    %slog:%s %s\n' "$MAUVE" "$R" "$DIM" "$R" \
    "$([[ $STYLE == bar ]] && echo 'progress bar' || echo 'moon spinner')" "$DIM" "$R" "$LOG"
  printf '%s╰────────────────────────────────────────────────────────%s\n\n' "$MAUVE" "$R"

  [[ $ASSUME_YES -eq 1 ]] && return
  read -rp "$(printf '%sProceed with installation?%s [y/N] ' "$B" "$R")" a
  [[ "${a,,}" == y* ]] || die "Cancelled."
  echo
}

fmt_list() { local IFS=' '; printf '%s' "${GREY}$*${R}"; }

# ══════════════════════════════════════════════════════════════════
#  DISPLAY: run a phase fn in the background, animate, log everything
# ══════════════════════════════════════════════════════════════════
PHASE_NO=0
phase() {                      # phase "Label" function_name
  local label="$1" fn="$2"
  PHASE_NO=$((PHASE_NO+1))
  logh "[$PHASE_NO/$PHASE_TOTAL] $label"
  ( "$fn" ) >>"$LOG" 2>&1 &
  local pid=$!
  if [[ "$STYLE" == bar ]]; then bar_anim "$pid" "$label"; else spin_anim "$pid" "$label"; fi
  wait "$pid"; local rc=$?
  end_line "$rc" "$label"
  if [[ $rc -ne 0 ]]; then
    warn "Phase '$label' exited $rc - see log:"
    tail -n 15 "$LOG" | sed 's/^/    /' >&2
  fi
  return $rc
}

spin_anim() {
  local pid="$1" label="$2" i=0
  tput civis 2>/dev/null
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r\e[K %s  %s %s…%s' "${MOON[$((i % 8))]}" "$label" "$GREY" "$R"
    i=$((i+1)); sleep 0.12
  done
  tput cnorm 2>/dev/null
}

bar_anim() {
  local pid="$1" label="$2" i=0 width=22
  local pct=$(( (PHASE_NO-1) * 100 / PHASE_TOTAL ))
  local fill=$(( pct * width / 100 ))
  tput civis 2>/dev/null
  while kill -0 "$pid" 2>/dev/null; do
    local bar="" j
    for ((j=0; j<width; j++)); do (( j<fill )) && bar+="█" || bar+="░"; done
    printf '\r\e[K %s %s%s%s %s%3d%%%s  %s' \
      "${MOON[$((i % 8))]}" "$GREEN" "$bar" "$R" "$B" "$pct" "$R" "$label"
    i=$((i+1)); sleep 0.12
  done
  tput cnorm 2>/dev/null
}

end_line() {
  local rc="$1" label="$2"
  printf '\r\e[K'
  if [[ $rc -eq 0 ]]; then printf ' %s✓%s %s\n' "$GREEN" "$R" "$label"
  else                     printf ' %s✗%s %s\n' "$RED" "$R" "$label"; fi
}

# helper used inside phases: log a command and run it
run() { log "+ $*"; "$@"; }

# ══════════════════════════════════════════════════════════════════
#  PHASES
# ══════════════════════════════════════════════════════════════════
AUR_HELPER="yay"

ph_aur_helper() {
  if command -v yay >/dev/null;  then AUR_HELPER=yay;  log "yay present";  return 0; fi
  if command -v paru >/dev/null; then AUR_HELPER=paru; log "paru present"; return 0; fi
  run sudo pacman -S --needed --noconfirm base-devel git || return 1
  local tmp; tmp="$(mktemp -d)"
  run git clone https://aur.archlinux.org/yay.git "$tmp/yay" || return 1
  ( cd "$tmp/yay" && makepkg -si --noconfirm ) || return 1
  rm -rf "$tmp"
  AUR_HELPER=yay
}

ph_multilib() {
  if grep -q '^\[multilib\]' /etc/pacman.conf; then
    log "multilib already enabled"; run sudo pacman -Sy --noconfirm; return $?
  fi
  log "enabling [multilib]"
  run sudo sed -i '/^#\[multilib\]/,/^#Include = .*mirrorlist/ s/^#//' /etc/pacman.conf || return 1
  run sudo pacman -Sy --noconfirm
}

ph_pacman() {
  run sudo pacman -S --needed --noconfirm "${PAC[@]}"
}

ph_aur() {
  [[ ${#AUR[@]} -eq 0 ]] && return 0
  run "$AUR_HELPER" -S --needed --noconfirm --answerdiff=None --answerclean=None "${AUR[@]}"
}

ph_services() {
  run sudo systemctl enable --now NetworkManager || warn "NetworkManager enable failed"
  run sudo systemctl enable --now bluetooth      || warn "bluetooth enable failed"
  run sudo systemctl enable --now keyd           || warn "keyd enable failed"
  # enable (not --now) so we don't kill the current TTY session mid-install
  run sudo systemctl enable sddm                 || warn "sddm enable failed"
  return 0
}

BACKUP=""
ph_deploy() {
  BACKUP="$HOME/.config/moonlit-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$HOME/.config"
  local c
  for c in "${CFG[@]}"; do
    [[ -d ".config/$c" ]] || { log "skip missing config: $c"; continue; }
    if [[ -e "$HOME/.config/$c" ]]; then
      mkdir -p "$BACKUP"
      run cp -a "$HOME/.config/$c" "$BACKUP/" || warn "backup of $c failed"
    fi
    mkdir -p "$HOME/.config/$c"
    run cp -a ".config/$c/." "$HOME/.config/$c/" || return 1
  done
  # keyd reads /etc, not ~/.config
  if [[ -f .config/keyd/default.conf ]]; then
    run sudo install -Dm644 .config/keyd/default.conf /etc/keyd/default.conf || warn "keyd /etc copy failed"
    run sudo keyd reload 2>/dev/null || true
  fi
  [[ -n "$BACKUP" && -d "$BACKUP" ]] && log "previous configs backed up to: $BACKUP"
  return 0
}

ph_themes() {
  # cursor (bundled)
  mkdir -p "$HOME/.icons"
  [[ -d .icons/Bibata-Modern-Classic ]] && run cp -an .icons/Bibata-Modern-Classic "$HOME/.icons/" 2>/dev/null
  # GTK catppuccin
  mkdir -p "$HOME/.themes"
  local url="https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-lavender-standard+default.zip"
  if run curl -fsSL "$url" -o /tmp/moonlit-gtk.zip; then
    run unzip -oq /tmp/moonlit-gtk.zip -d "$HOME/.themes/" || warn "GTK theme unzip failed"
  else
    warn "GTK theme download failed (non-fatal)"
  fi
  # SDDM theme - full tier only
  if [[ $SDDM_THEME -eq 1 ]]; then
    local tmp; tmp="$(mktemp -d)"
    if run git clone --depth 1 https://github.com/catppuccin/sddm.git "$tmp/sddm"; then
      run sudo cp -r "$tmp/sddm/src" /usr/share/sddm/themes/catppuccin-mocha-mauve || warn "SDDM theme copy failed"
      run sudo install -Dm644 sddm/sddm.conf /etc/sddm.conf.d/10-theme.conf || warn "SDDM conf failed"
      # background the sddm user can read (real file, no symlink)
      local wp="$HOME/Pictures/Wallpapers/wallpaper4.jpg"
      [[ -f "$wp" ]] || wp="$(find "$REPO/Wallpapers" -type f 2>/dev/null | head -1)"
      [[ -f "$wp" ]] && run sudo cp "$wp" /usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/wall.png 2>/dev/null
    else
      warn "SDDM theme clone failed (non-fatal)"
    fi
    rm -rf "$tmp"
  fi
  return 0
}

ph_post() {
  # fix hardcoded /home/fiw paths in deployed quickshell config
  local wpqml="$HOME/.config/quickshell/panels/WallpaperPanel.qml"
  [[ -f "$wpqml" ]] && run sed -i "s|/home/fiw/|$HOME/|g" "$wpqml"

  # wallpapers
  mkdir -p "$HOME/Pictures/Wallpapers"
  [[ -d Wallpapers ]] && run cp -an Wallpapers/. "$HOME/Pictures/Wallpapers/" 2>/dev/null

  # seed wallpaper cache so hyprlock has a background on first boot
  mkdir -p "$HOME/.cache"
  local first="$HOME/Pictures/Wallpapers/wallpaper4.jpg"
  [[ -f "$first" ]] || first="$(find "$HOME/Pictures/Wallpapers" -type f 2>/dev/null | head -1)"
  [[ -n "$first" ]] && printf '%s' "$first" >"$HOME/.cache/wallpaper-current"

  # make lock script executable
  [[ -f "$HOME/.config/hypr/scripts/lock.sh" ]] && run chmod +x "$HOME/.config/hypr/scripts/lock.sh"

  # neovim plugins (dev/full)
  if [[ $NVIM_SYNC -eq 1 ]] && command -v nvim >/dev/null; then
    run timeout 300 nvim --headless "+Lazy! sync" +qa 2>/dev/null || warn "nvim plugin sync timed out / failed (run it later)"
  fi
  return 0
}

# ── final niceties (interactive, outside the phase animations) ────
maybe_chsh() {
  command -v fish >/dev/null || return 0
  local fishbin; fishbin="$(command -v fish)"
  [[ "${SHELL:-}" == "$fishbin" ]] && return 0
  [[ $ASSUME_YES -eq 1 || ! -t 0 ]] && return 0
  read -rp "$(printf 'Set %sfish%s as your default login shell? [Y/n] ' "$MAUVE" "$R")" a
  if [[ "${a,,}" != n* ]]; then
    grep -qx "$fishbin" /etc/shells || echo "$fishbin" | sudo tee -a /etc/shells >/dev/null
    if chsh -s "$fishbin"; then ok "default shell → fish (re-login to apply)"; else warn "chsh failed"; fi
  fi
}

farewell() {
  printf '\n'
  printf ' %s🌕  Moonlit Shell installed (%s tier)%s\n' "$GREEN" "${TIER^}" "$R"
  [[ -n "$BACKUP" && -d "$BACKUP" ]] && printf '    %sold configs backed up:%s %s\n' "$GREY" "$R" "$BACKUP"
  printf '    %sfull log:%s %s\n\n' "$GREY" "$R" "$LOG"
  printf ' %sNext:%s\n' "$B$LAV" "$R"
  printf '   • reboot, then log in from the %sSDDM%s screen\n' "$MAUVE" "$R"
  printf '   • or start now from a TTY:  %sHyprland%s\n' "$SKY" "$R"
  printf '   • keys: %sSUPER+Space%s rofi · %sSUPER+B%s wallpapers · %sSUPER+Q%s kitty\n' \
    "$MAUVE" "$R" "$MAUVE" "$R" "$MAUVE" "$R"
  printf '   • if something looks off, see %sMANUAL-INSTALL.md%s\n\n' "$DIM" "$R"
}

# ══════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════
main() {
  banner
  preflight
  choose_tier
  build_sets
  summary
  get_sudo

  info "Starting - live progress below, every command goes to the log."
  echo

  phase "Ensuring AUR helper (yay)"        ph_aur_helper || die "Could not set up an AUR helper."
  [[ $MULTILIB -eq 1 ]] && { phase "Enabling [multilib] repo" ph_multilib || warn "multilib step failed"; }
  phase "Installing packages (pacman)"     ph_pacman     || die "Package installation failed."
  phase "Building AUR packages"            ph_aur        || warn "Some AUR packages failed - check the log."
  phase "Enabling system services"         ph_services
  phase "Deploying dotfiles"               ph_deploy     || die "Deploying configs failed."
  phase "Installing themes"                ph_themes
  phase "Post-install setup"               ph_post

  maybe_chsh
  farewell
}

main "$@"
