#!/usr/bin/env bash
# > prefix = quicklinks, ! prefix = file search, default = pinned apps

input="${1:-}"
retv="${ROFI_RETV:-0}"

# Handle selection — $1 is the displayed text, ROFI_INFO is unreliable in 2.x
if [[ "$retv" -ge 1 ]]; then
    item="$1"
    # File search results: item text is the path
    if [[ -e "$item" ]]; then
        xdg-open "$item" &>/dev/null &
        exit 0
    fi
    # Quicklinks: match on label text
    case "$item" in
        *GitHub*)   xdg-open "https://github.com" &>/dev/null & ;;
        *YouTube*)  xdg-open "https://youtube.com" &>/dev/null & ;;
        *Gmail*)    xdg-open "https://mail.google.com" &>/dev/null & ;;
        *ChatGPT*)  xdg-open "https://chatgpt.com" &>/dev/null & ;;
        *Twitch*)   xdg-open "https://twitch.tv" &>/dev/null & ;;
        *Reddit*)   xdg-open "https://reddit.com" &>/dev/null & ;;
    esac
    # Pinned apps
    case "$item" in
        Firefox)  hyprctl dispatch exec firefox ;;
        Discord)  hyprctl dispatch exec discord ;;
        Kitty)    hyprctl dispatch exec kitty ;;
        Spotify)  hyprctl dispatch exec spotify-launcher ;;
        Steam)    hyprctl dispatch exec steam ;;
        "VS Code") hyprctl dispatch exec code-oss ;;
    esac
    exit 0
fi

# > quicklinks
if [[ "$input" == ">"* ]]; then
    printf '\x00prompt\x1f>\n'
    printf '\x00theme\x1flistview { columns: 1; lines: 8; }\n'
    q="${input:1}"; q="${q# }"
    links=(
        "  GitHub|url:https://github.com"
        "  YouTube|url:https://youtube.com"
        "  Gmail|url:https://mail.google.com"
        "  ChatGPT|url:https://chatgpt.com"
        "  Twitch|url:https://twitch.tv"
        "  Reddit|url:https://reddit.com"
    )
    for e in "${links[@]}"; do
        name="${e%%|*}"; info="${e##*|}"
        plain="${name//[^a-zA-Z ]/}"
        [[ -z "$q" || "${plain,,}" == *"${q,,}"* ]] && printf '%s\x00info\x1f%s\n' "$name" "$info"
    done
    exit 0
fi

# ! file search
if [[ "$input" == "!"* ]]; then
    printf '\x00prompt\x1f!\n'
    printf '\x00theme\x1flistview { columns: 1; lines: 10; }\n'
    q="${input:1}"; q="${q# }"
    if [[ -z "$q" ]]; then
        printf 'Type to search files\xe2\x80\xa6\n'
    else
        find "$HOME" -maxdepth 6 -iname "*${q}*" \
            -not -path "*/.git/*" -not -path "*/node_modules/*" \
            2>/dev/null | head -20 | \
        while IFS= read -r f; do
            printf '%s\x00info\x1ffile:%s\n' "$f" "$f"
        done
    fi
    exit 0
fi

# Default: pinned apps
printf '\x00theme\x1flistview { columns: 3; lines: 2; }\n'

apps=(
    "Firefox|firefox|run:firefox"
    "Discord|discord|run:discord"
    "Kitty|kitty|run:kitty"
    "Spotify|spotify-launcher|run:spotify-launcher"
    "Steam|steam|run:steam"
    "VS Code|com.visualstudio.code.oss|run:code-oss"
)
for e in "${apps[@]}"; do
    IFS='|' read -r name icon info <<< "$e"
    printf '%s\x00icon\x1f%s\x00info\x1f%s\n' "$name" "$icon" "$info"
done
