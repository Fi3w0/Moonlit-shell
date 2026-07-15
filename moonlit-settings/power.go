package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
// governor needs root, so this has to run as root at boot — a --user unit
// can't get there on its own.
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

// runSudo runs argv as root via `sudo -S`, feeding the password on stdin so
// it never appears in argv or `ps`. -k drops any cached sudo timestamp
// first, so the password just typed into the app is always the one that
// actually gets checked, not silently skipped because some unrelated
// terminal still has an active sudo session.
func runSudo(password string, argv ...string) error {
	return runSudoStdin(password, "", argv...)
}

// runSudoStdin is runSudo but also forwards extraStdin to the target
// command after the password line — e.g. `sudo -S tee <path>` reading the
// file content it should write straight from stdin, no shell quoting of
// file contents needed anywhere.
func runSudoStdin(password, extraStdin string, argv ...string) error {
	cmd := exec.Command("sudo", append([]string{"-k", "-S"}, argv...)...)
	cmd.Stdin = strings.NewReader(password + "\n" + extraStdin)
	out, err := cmd.CombinedOutput()
	if err != nil {
		text := string(out)
		switch {
		case strings.Contains(text, "Sorry, try again") || strings.Contains(text, "incorrect password attempt"):
			return fmt.Errorf("incorrect password")
		case strings.Contains(text, "not in the sudoers"):
			return fmt.Errorf("this user is not allowed to use sudo")
		}
		msg := strings.TrimSpace(text)
		if msg == "" {
			msg = err.Error()
		}
		return fmt.Errorf("%s", msg)
	}
	return nil
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func cleanupOldUserPowerService() {
	if old := oldUserPowerServicePath(); fileExists(old) {
		exec.Command("systemctl", "--user", "disable", "--now", "moonlit-power.service").Run()
		os.Remove(old)
	}
}

// installPowerService writes and enables the persistence unit. Two sudo
// calls, but only one password prompt in the UI — both reuse the same
// typed password.
func installPowerService(password, gov string) error {
	cleanupOldUserPowerService()
	if !validGovernors[gov] {
		return fmt.Errorf("refusing to persist unknown governor %q", gov)
	}
	if err := runSudoStdin(password, renderPowerService(gov), "tee", powerServicePath()); err != nil {
		return fmt.Errorf("writing service file: %w", err)
	}
	if err := runSudo(password, "systemctl", "daemon-reload"); err != nil {
		return fmt.Errorf("daemon-reload: %w", err)
	}
	if err := runSudo(password, "systemctl", "enable", "--now", "moonlit-power.service"); err != nil {
		return fmt.Errorf("enabling service: %w", err)
	}
	return nil
}

func removePowerService(password string) error {
	cleanupOldUserPowerService()
	if err := runSudo(password, "systemctl", "disable", "--now", "moonlit-power.service"); err != nil {
		// Not installed is fine; anything else is worth surfacing.
		if !strings.Contains(err.Error(), "does not exist") && !strings.Contains(err.Error(), "not loaded") {
			return fmt.Errorf("disabling service: %w", err)
		}
	}
	if err := runSudo(password, "rm", "-f", powerServicePath()); err != nil {
		return fmt.Errorf("removing service file: %w", err)
	}
	return runSudo(password, "systemctl", "daemon-reload")
}
