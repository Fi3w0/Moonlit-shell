package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// HyprSettings are the "hard" knobs — they need `hyprctl reload` and can, in
// principle, change how the whole WM feels. Bounded to safe ranges by the UI.
type HyprSettings struct {
	Rounding        int     `json:"rounding"`        // 0 = sharp edges … 20 = very round
	ActiveOpacity   float64 `json:"activeOpacity"`   // 0.5 … 1.0
	InactiveOpacity float64 `json:"inactiveOpacity"` // 0.5 … 1.0
	GapsIn          int     `json:"gapsIn"`          // 0 … 30
	GapsOut         int     `json:"gapsOut"`         // 0 … 40
	BorderSize      int     `json:"borderSize"`      // 0 … 6
	BorderOverride  bool    `json:"borderOverride"`  // off = keep the base gradient border
	BorderActive    string  `json:"borderActive"`    // hex, used only when BorderOverride
	BorderInactive  string  `json:"borderInactive"`  // hex, used only when BorderOverride
	BlurEnabled     bool    `json:"blurEnabled"`
	BlurSize        int     `json:"blurSize"` // 0 … 12
	ShadowEnabled   bool    `json:"shadowEnabled"`
	AnimEnabled     bool    `json:"animEnabled"`
}

// Keybind is one rebindable action. Combo is "MODS, KEY" (Hyprland syntax);
// Dispatcher is the fixed action (e.g. "exec, kitty"). Default lets us unbind
// the original before binding the new combo, so overrides stay clean.
type Keybind struct {
	Combo      string `json:"combo"`
	Default    string `json:"-"`
	Dispatcher string `json:"-"`
	Label      string `json:"-"`
}

// Config is the app's full state. The shell reads `accent` and `barStyle`
// live; `hyprland` and `keybinds` are rendered into ~/.config/hypr/moonlit.conf
// only when the user hits Apply.
type Config struct {
	Accent        string             `json:"accent"`
	ArchLogoColor string             `json:"archLogoColor"` // bar's Arch logo — independent of accent
	Flavor        string             `json:"flavor"`      // mocha | macchiato | frappe | latte
	BarStyle      string             `json:"barStyle"`    // "islands" | "classic"
	BarPosition   string             `json:"barPosition"` // "top" | "left" | "right"
	BarOpacity    float64            `json:"barOpacity"`
	Clock24h      bool               `json:"clock24h"`
	ShowUpdates   bool               `json:"showUpdates"`
	ShowTemp      bool               `json:"showTemp"`
	ShowBattery   bool               `json:"showBattery"`
	ShowRecording bool               `json:"showRecording"`
	ToastDuration int                `json:"toastDuration"` // ms, 1000-10000
	MaxToasts     int                `json:"maxToasts"`     // 1-10
	ToastPosition string             `json:"toastPosition"` // "auto" | "top-right" | ...
	WallpaperDir  string             `json:"wallpaperDir"`   // path, default ~/Pictures/Wallpapers
	PowerProfile  string             `json:"powerProfile"`   // powersave | schedutil | performance
	PowerPersist  bool               `json:"powerPersist"`   // enable systemd service for reboot survival
	WallustEnabled bool              `json:"wallustEnabled"`  // auto-generate accent from wallpaper
	RofiAccent    string             `json:"rofiAccent"` // rofi prompt icon + selected-item border
	Hypr          HyprSettings       `json:"hyprland"`
	Keybinds      map[string]Keybind `json:"keybinds"`
}

// curatedKeybinds is the safe, fixed set the app is willing to rebind. The
// dispatcher/label/default never change; only the user's combo does.
func curatedKeybinds() map[string]Keybind {
	return map[string]Keybind{
		"terminal":   {Label: "Terminal", Default: "SUPER, Q", Combo: "SUPER, Q", Dispatcher: "exec, kitty"},
		"launcher":   {Label: "App launcher", Default: "SUPER, Space", Combo: "SUPER, Space", Dispatcher: "exec, rofi -show combi"},
		"close":      {Label: "Close window", Default: "SUPER, W", Combo: "SUPER, W", Dispatcher: "killactive"},
		"fullscreen": {Label: "Fullscreen", Default: "SUPER, F", Combo: "SUPER, F", Dispatcher: "fullscreen"},
		"float":      {Label: "Toggle floating", Default: "SUPER, P", Combo: "SUPER, P", Dispatcher: "togglefloating"},
	}
}

func defaultConfig() Config {
	return Config{
		Accent:        "#cba6f7", // moonlight mauve
		ArchLogoColor: "#eba0ac", // Catppuccin maroon (rose/red)
		RofiAccent:    "#f38ba8", // Catppuccin pink — matches the theme's current default
		Flavor:        "mocha",
		BarStyle:      "islands",
		BarPosition:   "top",
		BarOpacity:    0.72,
		Clock24h:      true,
		ShowUpdates:   true,
		ShowTemp:      true,
		ShowBattery:   true,
		ShowRecording: true,
		ToastDuration: 4200,
		MaxToasts:     5,
		ToastPosition: "auto",
		WallpaperDir:  "~/Pictures/Wallpapers",
		PowerProfile:  "schedutil",
		PowerPersist:  false,
		WallustEnabled: false,
		Hypr: HyprSettings{
			Rounding: 10, ActiveOpacity: 1.0, InactiveOpacity: 0.92,
			GapsIn: 3, GapsOut: 8, BorderSize: 2,
			BorderOverride: false, BorderActive: "#cba6f7", BorderInactive: "#45475a",
			BlurEnabled: true, BlurSize: 4, ShadowEnabled: true, AnimEnabled: true,
		},
		Keybinds:      curatedKeybinds(),
	}
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "moonlit", "config.json")
}

// isFirstRun is true until the config file exists — writing it (the wizard's
// "Get Started") is what ends the first-run state, so no separate flag file is
// needed.
func isFirstRun() bool {
	_, err := os.Stat(configPath())
	return os.IsNotExist(err)
}

// mergeKeybinds re-attaches the curated, non-persisted keybind metadata
// (label/dispatcher/default — all `json:"-"`) to whatever combos were loaded
// from JSON, whether from config.json or an imported file.
func mergeKeybinds(saved map[string]Keybind) map[string]Keybind {
	merged := curatedKeybinds()
	for id, def := range merged {
		if s, ok := saved[id]; ok && s.Combo != "" {
			def.Combo = s.Combo
		}
		merged[id] = def
	}
	return merged
}

// loadConfig merges the saved file over defaults, so new fields always have
// sane values and the curated keybind metadata (label/dispatcher) is restored.
func loadConfig() Config {
	c := defaultConfig()
	if data, err := os.ReadFile(configPath()); err == nil {
		_ = json.Unmarshal(data, &c)
	}
	c.Keybinds = mergeKeybinds(c.Keybinds)
	return c
}

func saveConfig(c Config) error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	p := configPath()

	// Auto-backup: snapshot the current config.json before overwriting.
	if existing, err := os.ReadFile(p); err == nil {
		backupDir := filepath.Join(filepath.Dir(p), "backups")
		os.MkdirAll(backupDir, 0o755)
		ts := time.Now().Format("20060102-150405")
		os.WriteFile(filepath.Join(backupDir, fmt.Sprintf("config-%s.json", ts)), existing, 0o644)

		// Prune: keep only the 50 most recent backups.
		if entries, e := os.ReadDir(backupDir); e == nil && len(entries) > 50 {
			sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
			for i := 0; i < len(entries)-50; i++ {
				os.Remove(filepath.Join(backupDir, entries[i].Name()))
			}
		}
	}

	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return os.WriteFile(p, data, 0o644)
}
