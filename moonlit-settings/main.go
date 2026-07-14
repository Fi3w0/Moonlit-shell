// moonlit-settings — a tiny GUI that edits the safe, bounded knobs of
// Moonlit Shell. It never touches QML or Hyprland config directly; it only
// writes ~/.config/moonlit/config.json, which the shell reads live. So it
// physically cannot produce a broken desktop.
package main

import (
	"encoding/json"
	"fmt"
	"image/color"
	"os"
	"path/filepath"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

// Config mirrors ~/.config/moonlit/config.json. Add fields as the app grows.
type Config struct {
	Accent string `json:"accent"`
}

func defaultConfig() Config {
	return Config{Accent: "#cba6f7"} // moonlight mauve
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "moonlit", "config.json")
}

func loadConfig() Config {
	c := defaultConfig()
	if data, err := os.ReadFile(configPath()); err == nil {
		_ = json.Unmarshal(data, &c)
	}
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

// hexToColor parses "#rrggbb" (falls back to mauve on bad input).
func hexToColor(hex string) color.Color {
	var r, g, b uint8
	if _, err := fmt.Sscanf(hex, "#%02x%02x%02x", &r, &g, &b); err != nil {
		return color.NRGBA{R: 0xcb, G: 0xa6, B: 0xf7, A: 0xff}
	}
	return color.NRGBA{R: r, G: g, B: b, A: 0xff}
}

func colorToHex(c color.Color) string {
	nc := color.NRGBAModel.Convert(c).(color.NRGBA)
	return fmt.Sprintf("#%02x%02x%02x", nc.R, nc.G, nc.B)
}

func main() {
	a := app.NewWithID("dev.fiw.moonlit-settings")
	w := a.NewWindow("Moonlit Settings")

	cfg := loadConfig()

	title := widget.NewLabelWithStyle("Moonlit Shell", fyne.TextAlignLeading,
		fyne.TextStyle{Bold: true})
	subtitle := widget.NewLabel("Theme")
	subtitle.Importance = widget.LowImportance

	// Accent row: swatch + hex label + pick button. The swatch previews the
	// live accent; picking one writes config.json and the shell recolors.
	swatch := canvas.NewRectangle(hexToColor(cfg.Accent))
	swatch.SetMinSize(fyne.NewSize(48, 48))
	swatch.CornerRadius = 10

	hexLabel := widget.NewLabel(cfg.Accent)

	apply := func(c color.Color) {
		cfg.Accent = colorToHex(c)
		swatch.FillColor = c
		swatch.Refresh()
		hexLabel.SetText(cfg.Accent)
		if err := saveConfig(cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}

	pick := widget.NewButton("Pick accent…", func() {
		picker := dialog.NewColorPicker("Accent color", "Drives active & hover states", apply, w)
		picker.Advanced = true
		picker.Show()
	})
	pick.Importance = widget.HighImportance

	reset := widget.NewButton("Reset", func() {
		apply(hexToColor(defaultConfig().Accent))
	})

	accentRow := container.NewBorder(nil, nil,
		container.NewCenter(swatch),
		container.NewHBox(reset, pick),
		container.NewVBox(widget.NewLabel("Accent"), hexLabel),
	)

	content := container.New(layout.NewVBoxLayout(),
		title, subtitle,
		widget.NewSeparator(),
		accentRow,
	)

	w.SetContent(container.NewPadded(content))
	w.Resize(fyne.NewSize(420, 220))
	w.ShowAndRun()
}
