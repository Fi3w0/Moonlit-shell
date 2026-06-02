#!/bin/sh
# Read current wallpaper path and launch hyprlock with it
export WALLPAPER=$(cat ~/.cache/wallpaper-current 2>/dev/null)
exec hyprlock
