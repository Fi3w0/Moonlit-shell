#!/usr/bin/env bash
# Keybinds cheatsheet rofi mode. Parses the live Hyprland bind files directly,
# so it never drifts from what's actually bound. Selecting a row copies the
# shortcut text to the clipboard (handy for docs/reference).

retv="${ROFI_RETV:-0}"
input="${1:-}"

FILES=(
    "$HOME/.config/hypr/keybinds.conf"
    "$HOME/.config/hypr/moonlit.conf"   # settings-app overrides, if any
)

mod_label() {
    local out="" m
    for m in $1; do
        case "$m" in
            SUPER)   out+="Super + " ;;
            SHIFT)   out+="Shift + " ;;
            CTRL|CONTROL) out+="Ctrl + " ;;
            ALT)     out+="Alt + " ;;
            *)       out+="$m + " ;;
        esac
    done
    printf '%s' "$out"
}

key_label() {
    case "$1" in
        comma) printf ',' ;;
        mouse:272) printf 'Mouse Left' ;;
        mouse:273) printf 'Mouse Right' ;;
        XF86MonBrightnessUp) printf 'Brightness Up' ;;
        XF86MonBrightnessDown) printf 'Brightness Down' ;;
        *) printf '%s' "$1" ;;
    esac
}

if [[ "$retv" -ge 1 ]]; then
    combo="${input%%  →*}"
    printf '%s' "$combo" | wl-copy
    qs ipc call notify send Moonlit "Copied" "$combo copied to clipboard" &>/dev/null &
    exit 0
fi

printf '\x00prompt\x1fkeybinds\n'

q="${input,,}"
declare -A vars=()
for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
        [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]] && {
            vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        }
    done < "$f"
done

expand_vars() {
    local s="$1" k
    for k in "${!vars[@]}"; do
        s="${s//\$$k/${vars[$k]}}"
    done
    printf '%s' "$s"
}

for f in "${FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r line; do
        [[ "$line" =~ ^bind[a-z]*[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
        rest="$(expand_vars "${BASH_REMATCH[1]}")"
        IFS=',' read -r mods key dispatcher args <<< "$rest"
        mods="$(echo "$mods" | xargs)"
        key="$(echo "$key" | xargs)"
        dispatcher="$(echo "$dispatcher" | xargs)"
        args="$(echo "$args" | xargs)"
        [[ -z "$key" ]] && continue

        combo="$(mod_label "$mods")$(key_label "$key")"
        action="$dispatcher"
        [[ -n "$args" ]] && action+=", $args"

        row="${combo}  →  ${action}"
        if [[ -z "$q" || "${row,,}" == *"$q"* ]]; then
            printf '%s\n' "$row"
        fi
    done < "$f"
done
