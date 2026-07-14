package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// HyprSettings are the "hard" knobs — they need `hyprctl reload` and can, in
// principle, change how the whole WM feels. Bounded to safe ranges by the UI.
type HyprSettings struct {
	Rounding        int     `json:"rounding"`        // 0 = sharp edges … 20 = very round
	ActiveOpacity   float64 `json:"activeOpacity"`   // 0.5 … 1.0
	InactiveOpacity float64 `json:"inactiveOpacity"` // 0.5 … 1.0
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
	Flavor        string             `json:"flavor"` // mocha | macchiato | frappe | latte
	BarStyle      string             `json:"barStyle"` // "islands" | "classic"
	BarOpacity    float64            `json:"barOpacity"`
	Clock24h      bool               `json:"clock24h"`
	ShowUpdates   bool               `json:"showUpdates"`
	ShowTemp      bool               `json:"showTemp"`
	ShowBattery   bool               `json:"showBattery"`
	ShowRecording bool               `json:"showRecording"`
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
		Flavor:        "mocha",
		BarStyle:      "islands",
		BarOpacity:    0.72,
		Clock24h:      true,
		ShowUpdates:   true,
		ShowTemp:      true,
		ShowBattery:   true,
		ShowRecording: true,
		Hypr:          HyprSettings{Rounding: 10, ActiveOpacity: 1.0, InactiveOpacity: 0.92},
		Keybinds:      curatedKeybinds(),
	}
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "moonlit", "config.json")
}

// loadConfig merges the saved file over defaults, so new fields always have
// sane values and the curated keybind metadata (label/dispatcher) is restored.
func loadConfig() Config {
	c := defaultConfig()
	if data, err := os.ReadFile(configPath()); err == nil {
		_ = json.Unmarshal(data, &c)
	}
	// Re-attach non-persisted metadata to whatever combos were loaded.
	merged := curatedKeybinds()
	for id, def := range merged {
		if saved, ok := c.Keybinds[id]; ok && saved.Combo != "" {
			def.Combo = saved.Combo
		}
		merged[id] = def
	}
	c.Keybinds = merged
	return c
}

func saveConfig(c Config) error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	p := configPath()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return os.WriteFile(p, data, 0o644)
}
