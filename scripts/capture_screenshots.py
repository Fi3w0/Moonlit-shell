#!/usr/bin/env python3
"""Capture the curated README gallery screenshots for Moonlit Shell.

Drives the live Hyprland/Quickshell session directly (hyprctl + qs ipc),
so it must be run on the actual desktop, not headless. Any windows open
when the script starts are parked in a special workspace for the
duration and restored at the end.

Deliberately paced: every step waits for the compositor/blur/animation
to actually settle before grim fires, and spawned helper windows are
force-killed by PID (SIGKILL) rather than asked to close, since apps
like kitty can throw up a confirmation prompt on a normal close request
if a foreground process (ranger, etc.) is running inside.
"""
import json
import os
import signal
import subprocess
import time
from pathlib import Path

OUT_DIR = Path.home() / "moonlit-shell" / "assets" / "screenshots"
CONFIG_PATH = Path.home() / ".config" / "moonlit" / "config.json"

SETTLE = 1.5     # after opening/closing a panel, before it's considered "shown"
SPAWN_GAP = 1.2  # between spawning one helper window and the next, for tiling to settle
SPAWN_TIMEOUT = 6.0


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True, check=True).stdout


def clients():
    return json.loads(hyprctl("clients", "-j"))


def dispatch(*parts):
    hyprctl("dispatch", *parts)


def qs_ipc(*args):
    subprocess.run(["qs", "ipc", "call", *args], check=True)


def shot(name: str, delay: float = SETTLE):
    time.sleep(delay)
    path = OUT_DIR / f"{name}.png"
    subprocess.run(["grim", str(path)], check=True)
    print(f"  -> {path.name} ({path.stat().st_size // 1024} KB)")


def park_existing_windows():
    parked = [(c["address"], c["workspace"]["id"]) for c in clients()]
    for addr, _ in parked:
        dispatch("movetoworkspacesilent", f"special:scratch,address:{addr}")
    return parked


def restore_windows(parked):
    live = {c["address"] for c in clients()}
    for addr, ws in parked:
        if addr not in live:
            continue
        try:
            dispatch("movetoworkspacesilent", f"{ws},address:{addr}")
        except subprocess.CalledProcessError:
            print(f"  (couldn't restore {addr}, leaving as-is)")


def spawn_and_wait(cmd: list[str], match: str, timeout: float = SPAWN_TIMEOUT):
    """Spawn cmd, return (address, pid) of the new window whose class or
    title contains `match` (case-insensitive)."""
    before = {c["address"] for c in clients()}
    subprocess.Popen(cmd, start_new_session=True)
    deadline = time.time() + timeout
    needle = match.lower()
    while time.time() < deadline:
        for c in clients():
            if c["address"] in before:
                continue
            if needle in c["class"].lower() or needle in c["title"].lower():
                time.sleep(0.3)  # let it finish its first paint
                return c["address"], c["pid"]
        time.sleep(0.2)
    raise RuntimeError(f"no window matching {match!r} after spawning {cmd}")


def kill_pid(pid: int):
    """SIGKILL — bypasses kitty's close-confirmation prompt entirely."""
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def toggle_panel(name: str):
    qs_ipc("panel", "toggle", name)


def set_bar_position(position: str):
    cfg = json.loads(CONFIG_PATH.read_text())
    original = cfg.get("barPosition", "top")
    cfg["barPosition"] = position
    CONFIG_PATH.write_text(json.dumps(cfg, indent=4))
    time.sleep(1.0)  # live-reload settle
    return original


def prime_bar_title():
    """Bar shows the last-focused window's title even once nothing is
    focused. Open and close one clean-titled window first so that
    stale title is something innocuous, not whatever was open before
    this script ran."""
    addr, pid = spawn_and_wait(["kitty", "--title", "Desktop", "-e", "sleep", "1"], "Desktop")
    time.sleep(0.4)
    kill_pid(pid)
    time.sleep(0.4)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Parking existing windows...")
    parked = park_existing_windows()
    time.sleep(0.6)
    prime_bar_title()

    try:
        print("1/7 hero-desktop")
        shot("hero-desktop")

        print("2/7 rofi + system monitor")
        toggle_panel("sysmon")
        time.sleep(SETTLE)
        # Rofi renders as a layer-shell surface, not an xdg toplevel, so it
        # never shows up in `hyprctl clients` — just launch it, give it a
        # moment to paint, and kill the process directly afterward.
        rofi_proc = subprocess.Popen(["rofi", "-show", "combi"], start_new_session=True)
        time.sleep(1.0)
        shot("rofi-sysmon", delay=0.5)
        rofi_proc.kill()
        toggle_panel("sysmon")
        time.sleep(0.6)

        print("3/7 quick settings + OSD")
        toggle_panel("qs")
        time.sleep(SETTLE)
        qs_ipc("osd", "set", "volume", "65")
        shot("quick-settings-osd", delay=0.5)
        toggle_panel("qs")
        time.sleep(0.6)

        print("4/7 power menu")
        toggle_panel("power")
        shot("power-menu")
        toggle_panel("power")
        time.sleep(0.6)

        print("5/7 moonlit-settings")
        addr, pid = spawn_and_wait(["moonlit-settings"], "moonlit")
        shot("moonlit-settings", delay=1.6)
        kill_pid(pid)
        time.sleep(0.6)

        print("6/7 window overview (tiled apps)")
        bg = []
        bg.append(spawn_and_wait(["kitty", "--hold", "-e", "fastfetch"], "kitty"))
        time.sleep(SPAWN_GAP)
        bg.append(spawn_and_wait(["thunar"], "thunar", timeout=10.0))
        time.sleep(SPAWN_GAP)
        bg.append(spawn_and_wait(["kitty", "-e", "ranger"], "kitty"))
        time.sleep(SPAWN_GAP)
        toggle_panel("overview")
        shot("window-overview", delay=1.8)
        toggle_panel("overview")
        time.sleep(0.6)
        for _, pid in bg:
            kill_pid(pid)
        time.sleep(0.5)

        print("7/7 side bar (left) + audio panel")
        orig_pos = set_bar_position("left")
        toggle_panel("audio")
        shot("sidebar-left-audio")
        toggle_panel("audio")
        time.sleep(0.4)
        set_bar_position(orig_pos)
        time.sleep(1.0)

    finally:
        time.sleep(0.4)
        print("Restoring parked windows...")
        restore_windows(parked)

    print("Done.")


if __name__ == "__main__":
    main()
