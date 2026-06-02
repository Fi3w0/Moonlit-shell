#!/bin/sh
# Symlink current wallpaper so hyprlock can load it (doesn't support $ENV in paths)
WALL="$(cat ~/.cache/wallpaper-current 2>/dev/null)"
[ -n "$WALL" ] && ln -sf "$WALL" ~/.cache/lock-wallpaper
exec hyprlock
