#!/usr/bin/env bash
# Emoji picker rofi mode. Data: emoji-data.txt (tab-separated: emoji<TAB>keywords).
# Selecting an emoji copies it to the clipboard and shows a shell toast.

DATA="$(dirname "${BASH_SOURCE[0]}")/emoji-data.txt"
input="${1:-}"
retv="${ROFI_RETV:-0}"

if [[ "$retv" -ge 1 ]]; then
    emoji="$1"
    printf '%s' "$emoji" | wl-copy
    qs ipc call notify send Moonlit "Copied" "$emoji copied to clipboard" &>/dev/null &
    exit 0
fi

printf '\x00prompt\x1femoji\n'

q="${input,,}"
while IFS=$'\t' read -r emoji keywords; do
    [[ -z "$emoji" ]] && continue
    if [[ -z "$q" || "${keywords,,}" == *"$q"* ]]; then
        printf '%s\n' "$emoji"
    fi
done < "$DATA"
