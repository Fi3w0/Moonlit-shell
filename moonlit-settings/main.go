// moonlit-settings — a small GUI for the safe, bounded knobs of Moonlit Shell.
//
// Two kinds of change:
//   • Live  (theme, bar style) → written to ~/.config/moonlit/config.json,
//     which the shell reads instantly. Cannot break anything.
//   • Hard  (Hyprland rounding/opacity, keybinds) → rendered into
//     ~/.config/hypr/moonlit.conf and applied with `hyprctl reload` behind an
//     Apply button, with an at-your-own-risk note.
package main

import (
	"fmt"
	"image/color"
	"os"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/widget"
)

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

var keybindOrder = []string{"terminal", "launcher", "close", "fullscreen", "float"}

func main() {
	// Headless: `moonlit-settings apply` re-renders moonlit.conf from the
	// saved config and reloads Hyprland (handy for scripts / re-applying).
	if len(os.Args) > 1 && os.Args[1] == "apply" {
		if err := applyHypr(loadConfig()); err != nil {
			fmt.Fprintln(os.Stderr, "apply failed:", err)
			os.Exit(1)
		}
		fmt.Println("applied moonlit.conf + hyprctl reload")
		return
	}

	a := app.NewWithID("dev.fiw.moonlit-settings")
	a.Settings().SetTheme(moonlitTheme{})
	w := a.NewWindow("Moonlit Settings")

	cfg := loadConfig()

	tabs := container.NewAppTabs(
		container.NewTabItem("Theme", themeTab(&cfg, w)),
		container.NewTabItem("Hyprland", hyprTab(&cfg, w)),
		container.NewTabItem("Keybinds", keybindTab(&cfg, w)),
	)
	tabs.SetTabLocation(container.TabLocationTop)

	header := container.NewVBox(
		widget.NewLabelWithStyle("🌙  Moonlit Shell", fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
	)

	w.SetContent(container.NewBorder(header, nil, nil, nil, tabs))
	w.Resize(fyne.NewSize(460, 420))
	w.ShowAndRun()
}

// ── Theme tab: live changes (accent, bar style) ──────────────────────────
func themeTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	swatch := canvas.NewRectangle(hexToColor(cfg.Accent))
	swatch.SetMinSize(fyne.NewSize(44, 44))
	swatch.CornerRadius = 10
	hexLabel := widget.NewLabel(cfg.Accent)

	applyAccent := func(c color.Color) {
		cfg.Accent = colorToHex(c)
		swatch.FillColor = c
		swatch.Refresh()
		hexLabel.SetText(cfg.Accent)
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}
	pick := widget.NewButton("Pick…", func() {
		p := dialog.NewColorPicker("Accent color", "Active & hover across the shell", applyAccent, w)
		p.Advanced = true
		p.Show()
	})
	pick.Importance = widget.HighImportance
	reset := widget.NewButton("Reset", func() { applyAccent(hexToColor(defaultConfig().Accent)) })

	accentRow := container.NewBorder(nil, nil,
		container.NewHBox(container.NewCenter(swatch), hexLabel),
		container.NewHBox(reset, pick), nil)

	// Bar style — live. Shell swaps the bar layout on change.
	barChoice := widget.NewRadioGroup([]string{"Islands (floating)", "Classic (topbar)"}, func(s string) {
		if s == "Classic (topbar)" {
			cfg.BarStyle = "classic"
		} else {
			cfg.BarStyle = "islands"
		}
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	})
	barChoice.Horizontal = true
	if cfg.BarStyle == "classic" {
		barChoice.SetSelected("Classic (topbar)")
	} else {
		barChoice.SetSelected("Islands (floating)")
	}

	return container.NewVBox(
		sectionLabel("Accent"),
		accentRow,
		widget.NewSeparator(),
		sectionLabel("Top bar style"),
		barChoice,
		hint("Applies instantly — safe, can't break anything."),
	)
}

// ── Hyprland tab: hard changes behind Apply ──────────────────────────────
func hyprTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	roundVal := widget.NewLabel(fmt.Sprintf("%d px", cfg.Hypr.Rounding))
	round := widget.NewSlider(0, 20)
	round.Step = 1
	round.Value = float64(cfg.Hypr.Rounding)
	round.OnChanged = func(v float64) {
		cfg.Hypr.Rounding = int(v)
		roundVal.SetText(fmt.Sprintf("%d px", int(v)))
	}

	actVal := widget.NewLabel(fmt.Sprintf("%.0f%%", cfg.Hypr.ActiveOpacity*100))
	act := widget.NewSlider(0.5, 1.0)
	act.Step = 0.01
	act.Value = cfg.Hypr.ActiveOpacity
	act.OnChanged = func(v float64) {
		cfg.Hypr.ActiveOpacity = v
		actVal.SetText(fmt.Sprintf("%.0f%%", v*100))
	}

	inVal := widget.NewLabel(fmt.Sprintf("%.0f%%", cfg.Hypr.InactiveOpacity*100))
	inact := widget.NewSlider(0.5, 1.0)
	inact.Step = 0.01
	inact.Value = cfg.Hypr.InactiveOpacity
	inact.OnChanged = func(v float64) {
		cfg.Hypr.InactiveOpacity = v
		inVal.SetText(fmt.Sprintf("%.0f%%", v*100))
	}

	apply := widget.NewButton("Apply  (hyprctl reload)", func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
			return
		}
		if err := applyHypr(*cfg); err != nil {
			dialog.ShowError(err, w)
			return
		}
		dialog.ShowInformation("Applied", "Hyprland reloaded with your changes.", w)
	})
	apply.Importance = widget.HighImportance

	form := container.New(newLabeledGrid(),
		widget.NewLabel("Edge rounding"), sliderRow(round, roundVal),
		widget.NewLabel("Active opacity"), sliderRow(act, actVal),
		widget.NewLabel("Inactive opacity"), sliderRow(inact, inVal),
	)

	return container.NewVBox(
		warnBanner(),
		sectionLabel("Window decoration"),
		form,
		hint("Rounding: 0 = sharp corners, higher = rounder. Opacity pairs with the global blur for frosted glass."),
		widget.NewSeparator(),
		container.NewHBox(apply),
	)
}

// ── Keybind tab: hard changes behind Apply ───────────────────────────────
func keybindTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	rows := []fyne.CanvasObject{}
	entries := map[string]*widget.Entry{}
	for _, id := range keybindOrder {
		kb := cfg.Keybinds[id]
		e := widget.NewEntry()
		e.SetText(kb.Combo)
		e.SetPlaceHolder(kb.Default)
		entries[id] = e
		rows = append(rows, widget.NewLabel(kb.Label), e)
	}
	form := container.New(newLabeledGrid(), rows...)

	apply := widget.NewButton("Apply  (hyprctl reload)", func() {
		for _, id := range keybindOrder {
			kb := cfg.Keybinds[id]
			combo := entries[id].Text
			if combo == "" {
				combo = kb.Default
			}
			kb.Combo = combo
			cfg.Keybinds[id] = kb
		}
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
			return
		}
		if err := applyHypr(*cfg); err != nil {
			dialog.ShowError(err, w)
			return
		}
		dialog.ShowInformation("Applied", "Keybinds reloaded.", w)
	})
	apply.Importance = widget.HighImportance

	reset := widget.NewButton("Reset to defaults", func() {
		for _, id := range keybindOrder {
			entries[id].SetText(cfg.Keybinds[id].Default)
		}
	})

	return container.NewVBox(
		warnBanner(),
		sectionLabel("Rebind actions"),
		hint("Format: MODS, KEY  —  e.g.  SUPER, Q   or   SUPER SHIFT, Return"),
		form,
		widget.NewSeparator(),
		container.NewHBox(apply, reset),
	)
}

// ── little shared bits ───────────────────────────────────────────────────
func sectionLabel(s string) fyne.CanvasObject {
	return widget.NewLabelWithStyle(s, fyne.TextAlignLeading, fyne.TextStyle{Bold: true})
}

func hint(s string) fyne.CanvasObject {
	l := widget.NewLabel(s)
	l.Wrapping = fyne.TextWrapWord
	l.Importance = widget.LowImportance
	return l
}

func warnBanner() fyne.CanvasObject {
	l := widget.NewLabel("⚠  Advanced — these change Hyprland and take a reload. Safe defaults, but use at your own risk.")
	l.Wrapping = fyne.TextWrapWord
	l.Importance = widget.WarningImportance
	return l
}

func sliderRow(s *widget.Slider, val *widget.Label) fyne.CanvasObject {
	return container.NewBorder(nil, nil, nil, val, s)
}

// newLabeledGrid: two columns, left auto (labels), right stretches (controls).
func newLabeledGrid() fyne.Layout {
	return &labeledGrid{}
}

type labeledGrid struct{}

func (g *labeledGrid) MinSize(objs []fyne.CanvasObject) fyne.Size {
	labelW, h := float32(0), float32(0)
	for i := 0; i < len(objs); i += 2 {
		ls := objs[i].MinSize()
		if ls.Width > labelW {
			labelW = ls.Width
		}
		rh := ls.Height
		if i+1 < len(objs) {
			if ch := objs[i+1].MinSize().Height; ch > rh {
				rh = ch
			}
		}
		h += rh + 6
	}
	return fyne.NewSize(labelW+220, h)
}

func (g *labeledGrid) Layout(objs []fyne.CanvasObject, size fyne.Size) {
	labelW := float32(0)
	for i := 0; i < len(objs); i += 2 {
		if lw := objs[i].MinSize().Width; lw > labelW {
			labelW = lw
		}
	}
	gap := float32(10)
	y := float32(0)
	for i := 0; i < len(objs); i += 2 {
		rowH := objs[i].MinSize().Height
		if i+1 < len(objs) {
			if ch := objs[i+1].MinSize().Height; ch > rowH {
				rowH = ch
			}
		}
		objs[i].Move(fyne.NewPos(0, y))
		objs[i].Resize(fyne.NewSize(labelW, rowH))
		if i+1 < len(objs) {
			objs[i+1].Move(fyne.NewPos(labelW+gap, y))
			objs[i+1].Resize(fyne.NewSize(size.Width-labelW-gap, rowH))
		}
		y += rowH + 6
	}
}
