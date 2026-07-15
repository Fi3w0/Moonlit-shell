package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// validGovernors is the fixed whitelist of governor names this app will
// ever bake into a systemd unit or a privileged command. Defense in depth:
// callers already only pass values out of a fixed label map, but a unit
// file that runs unattended at every boot should never trust a string it
// didn't itself validate.
var validGovernors = map[string]bool{
	"powersave": true, "schedutil": true, "performance": true,
	"ondemand": true, "conservative": true,
}

// powerServicePath is a SYSTEM (root) unit, not a --user one. Applying a
// governor needs root — writing scaling_governor or running cpupower fails
// for a normal user. A --user service has no way to become root at boot
// (no polkit agent running that early, nothing to answer a password
// prompt), so it would silently fail every single boot. Installing this as
// a system unit needs one pkexec prompt now, when the user flips the
// toggle; after that systemd just runs it as root directly at every boot,
// no auth needed.
func powerServicePath() string {
	return "/etc/systemd/system/moonlit-power.service"
}

// oldUserPowerServicePath is where an earlier version of this app installed
// the service, as a --user unit that could never actually work. Clean it up
// so a silently-broken leftover doesn't linger alongside the real one.
func oldUserPowerServicePath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "systemd", "user", "moonlit-power.service")
}

// renderPowerService bakes the (validated) governor directly into the unit.
// No runtime config.json read, no python3 dependency, nothing to fail at
// boot besides cpupower/sysfs itself.
func renderPowerService(gov string) string {
	script := fmt.Sprintf(
		`if command -v cpupower >/dev/null; then cpupower frequency-set -g %s; `+
			`else echo %s | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null; fi`,
		gov, gov)
	return "[Unit]\n" +
		"Description=Moonlit Shell power profile\n\n" +
		"[Service]\n" +
		"Type=oneshot\n" +
		"ExecStart=/bin/sh -c \"" + script + "\"\n" +
		"RemainAfterExit=yes\n\n" +
		"[Install]\n" +
		"WantedBy=multi-user.target\n"
}

// syncPowerService installs or removes the system-level persistence unit.
// The unit content is base64-encoded before being embedded in the pkexec
// shell command, so nothing about it needs shell-quoting or escaping —
// there is no injection surface even though it's technically "interpolated
// into a shell string".
func syncPowerService(gov string, enable bool) error {
	// Best-effort cleanup of the old, broken --user unit from earlier
	// versions of this app, so it doesn't linger as a silently-failing
	// duplicate alongside the working system unit.
	if old := oldUserPowerServicePath(); fileExists(old) {
		exec.Command("systemctl", "--user", "disable", "--now", "moonlit-power.service").Run()
		os.Remove(old)
	}

	if !enable {
		cmd := exec.Command("pkexec", "sh", "-c", fmt.Sprintf(
			"systemctl disable --now moonlit-power.service 2>/dev/null; rm -f %s; systemctl daemon-reload",
			powerServicePath()))
		return cmd.Run()
	}

	if !validGovernors[gov] {
		return fmt.Errorf("refusing to persist unknown governor %q", gov)
	}

	encoded := base64.StdEncoding.EncodeToString([]byte(renderPowerService(gov)))
	script := fmt.Sprintf(
		"echo %s | base64 -d > %s && systemctl daemon-reload && systemctl enable --now moonlit-power.service",
		encoded, powerServicePath())
	return exec.Command("pkexec", "sh", "-c", script).Run()
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
