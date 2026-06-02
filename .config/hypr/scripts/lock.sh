#!/bin/sh
# Symlink current wallpaper so hyprlock can load it
WALL="$(cat ~/.cache/wallpaper-current 2>/dev/null)"
[ -n "$WALL" ] && ln -sf "$WALL" /tmp/lock-wallpaper
exec hyprlock
