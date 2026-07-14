// moonlit-settings — a small GUI for the safe, bounded knobs of Moonlit Shell.
//
// Two kinds of change:
//   • Live  (theme, bar style) → written to ~/.config/moonlit/config.json,
//     which the shell reads instantly. Cannot break anything.
//   • Hard  (Hyprland rounding/opacity, keybinds) → rendered into
//     ~/.config/hypr/moonlit.conf and applied with `hyprctl reload` behind an
//     Apply button, with an at-your-own-risk note.
//
// Every screen has a Reset to defaults, so nothing is a one-way door.
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
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
)

// Catppuccin Mocha, used for the few hand-drawn bits (swatch, wordmark).
const (
	cMauve    = "#cba6f7"
	cText     = "#cdd6f4"
	cOverlay  = "#6c7086"
	cSurface1 = "#45475a"
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
		container.NewTabItem("Keys", keybindTab(&cfg, w)),
	)
	tabs.SetTabLocation(container.TabLocationTop)

	w.SetContent(container.NewBorder(header(), nil, nil, nil, tabs))
	w.Resize(fyne.NewSize(480, 560))
	w.ShowAndRun()
}

// ── Signature header: mauve "Moonlit" wordmark + moon ────────────────────
func header() fyne.CanvasObject {
	moon := canvas.NewText("🌙", nil)
	moon.TextSize = 24

	word := canvas.NewText("Moonlit", hexToColor(cMauve))
	word.TextStyle = fyne.TextStyle{Bold: true}
	word.TextSize = 21

	tag := canvas.NewText("shell settings", hexToColor(cOverlay))
	tag.TextSize = 11

	title := container.NewHBox(
		container.NewCenter(moon),
		container.NewCenter(container.NewVBox(word, tag)),
	)
	return container.NewVBox(
		container.NewPadded(title),
		widget.NewSeparator(),
	)
}

// ── Theme tab: live changes + reset ──────────────────────────────────────
func themeTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	swatch := canvas.NewCircle(hexToColor(cfg.Accent))
	swatch.StrokeColor = hexToColor(cSurface1)
	swatch.StrokeWidth = 1
	swatchBox := container.NewGridWrap(fyne.NewSize(44, 44), swatch)
	hexLabel := canvas.NewText(cfg.Accent, hexToColor(cText))
	hexLabel.TextStyle = fyne.TextStyle{Monospace: true}
	hexLabel.TextSize = 15

	applyAccent := func(c color.Color) {
		cfg.Accent = colorToHex(c)
		swatch.FillColor = c
		swatch.Refresh()
		hexLabel.Text = cfg.Accent
		hexLabel.Refresh()
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

	accentCard := widget.NewCard("Accent", "Drives active & hover states across the shell",
		container.NewBorder(nil, nil,
			container.NewHBox(container.NewCenter(swatchBox), container.NewCenter(hexLabel)),
			container.NewCenter(pick), nil))

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
	setBar := func() {
		if cfg.BarStyle == "classic" {
			barChoice.SetSelected("Classic (topbar)")
		} else {
			barChoice.SetSelected("Islands (floating)")
		}
	}
	setBar()
	barCard := widget.NewCard("Top bar", "Floating pills or the classic solid bar", barChoice)

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.BarStyle = d.BarStyle
		setBar()
		applyAccent(hexToColor(d.Accent))
	})

	body := container.NewVBox(accentCard, barCard, hintText("Changes here apply instantly and can’t break anything."))
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}

// ── Hyprland tab: hard changes behind Apply + reset ──────────────────────
func hyprTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	roundVal := widget.NewLabel("")
	round := widget.NewSlider(0, 20)
	round.Step = 1
	inact := widget.NewSlider(0.5, 1.0)
	inact.Step = 0.01
	act := widget.NewSlider(0.5, 1.0)
	act.Step = 0.01
	inVal := widget.NewLabel("")
	actVal := widget.NewLabel("")

	sync := func() {
		round.Value = float64(cfg.Hypr.Rounding)
		round.Refresh()
		roundVal.SetText(fmt.Sprintf("%d px", cfg.Hypr.Rounding))
		act.Value = cfg.Hypr.ActiveOpacity
		act.Refresh()
		actVal.SetText(fmt.Sprintf("%.0f%%", cfg.Hypr.ActiveOpacity*100))
		inact.Value = cfg.Hypr.InactiveOpacity
		inact.Refresh()
		inVal.SetText(fmt.Sprintf("%.0f%%", cfg.Hypr.InactiveOpacity*100))
	}
	round.OnChanged = func(v float64) {
		cfg.Hypr.Rounding = int(v)
		roundVal.SetText(fmt.Sprintf("%d px", int(v)))
	}
	act.OnChanged = func(v float64) {
		cfg.Hypr.ActiveOpacity = v
		actVal.SetText(fmt.Sprintf("%.0f%%", v*100))
	}
	inact.OnChanged = func(v float64) {
		cfg.Hypr.InactiveOpacity = v
		inVal.SetText(fmt.Sprintf("%.0f%%", v*100))
	}
	sync()

	form := container.New(&labeledGrid{},
		widget.NewLabel("Edge rounding"), sliderRow(round, roundVal),
		widget.NewLabel("Active opacity"), sliderRow(act, actVal),
		widget.NewLabel("Inactive opacity"), sliderRow(inact, inVal),
	)
	decoCard := widget.NewCard("Window decoration", "0 = sharp corners · opacity pairs with the global blur", form)

	apply := widget.NewButton("Apply", func() {
		if err := saveApply(cfg, w); err == nil {
			dialog.ShowInformation("Applied", "Hyprland reloaded with your changes.", w)
		}
	})
	apply.Importance = widget.HighImportance
	reset := resetButton(func() {
		cfg.Hypr = defaultConfig().Hypr
		sync()
		saveApply(cfg, w)
	})

	body := container.NewVBox(warnBanner(), decoCard)
	return container.NewBorder(nil, footerApply(reset, apply), nil, nil, container.NewPadded(body))
}

// ── Keybinds tab: hard changes behind Apply + reset ──────────────────────
func keybindTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	entries := map[string]*widget.Entry{}
	rows := []fyne.CanvasObject{}
	for _, id := range keybindOrder {
		kb := cfg.Keybinds[id]
		e := widget.NewEntry()
		e.SetText(kb.Combo)
		e.SetPlaceHolder(kb.Default)
		entries[id] = e
		rows = append(rows, widget.NewLabel(kb.Label), e)
	}
	form := container.New(&labeledGrid{}, rows...)
	card := widget.NewCard("Shortcuts", "Format:  MODS, KEY   —   e.g.  SUPER, Q", form)

	commit := func() {
		for _, id := range keybindOrder {
			kb := cfg.Keybinds[id]
			if entries[id].Text != "" {
				kb.Combo = entries[id].Text
			} else {
				kb.Combo = kb.Default
			}
			cfg.Keybinds[id] = kb
		}
	}
	apply := widget.NewButton("Apply", func() {
		commit()
		if err := saveApply(cfg, w); err == nil {
			dialog.ShowInformation("Applied", "Keybinds reloaded.", w)
		}
	})
	apply.Importance = widget.HighImportance
	reset := resetButton(func() {
		for _, id := range keybindOrder {
			kb := cfg.Keybinds[id]
			kb.Combo = kb.Default
			cfg.Keybinds[id] = kb
			entries[id].SetText(kb.Default)
		}
		saveApply(cfg, w)
	})

	body := container.NewVBox(warnBanner(), card)
	return container.NewBorder(nil, footerApply(reset, apply), nil, nil, container.NewPadded(body))
}

// ── shared bits ──────────────────────────────────────────────────────────

// saveApply writes config.json then renders + reloads Hyprland. Shows any
// error and returns it so callers can skip their success toast.
func saveApply(cfg *Config, w fyne.Window) error {
	if err := saveConfig(*cfg); err != nil {
		dialog.ShowError(err, w)
		return err
	}
	if err := applyHypr(*cfg); err != nil {
		dialog.ShowError(err, w)
		return err
	}
	return nil
}

func resetButton(fn func()) *widget.Button {
	b := widget.NewButtonWithIcon("Reset to defaults", nil, fn)
	b.Importance = widget.LowImportance
	return b
}

// footer: just a reset, left-aligned at the bottom.
func footer(reset *widget.Button) fyne.CanvasObject {
	return container.NewVBox(widget.NewSeparator(),
		container.NewHBox(reset, layout.NewSpacer()))
}

// footerApply: reset on the left, prominent Apply on the right.
func footerApply(reset, apply *widget.Button) fyne.CanvasObject {
	return container.NewVBox(widget.NewSeparator(),
		container.NewBorder(nil, nil, reset, apply, nil))
}

func hintText(s string) fyne.CanvasObject {
	l := widget.NewLabel(s)
	l.Wrapping = fyne.TextWrapWord
	l.Importance = widget.LowImportance
	return l
}

func warnBanner() fyne.CanvasObject {
	l := widget.NewLabel("⚠  Advanced — these change Hyprland and need a reload. Safe defaults, but use at your own risk.")
	l.Wrapping = fyne.TextWrapWord
	l.Importance = widget.WarningImportance
	return container.NewPadded(l)
}

func sliderRow(s *widget.Slider, val *widget.Label) fyne.CanvasObject {
	return container.NewBorder(nil, nil, nil, val, s)
}

// labeledGrid: two columns — labels size to content, controls stretch.
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
		h += rh + 8
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
	gap := float32(12)
	y := float32(0)
	for i := 0; i < len(objs); i += 2 {
		rowH := objs[i].MinSize().Height
		if i+1 < len(objs) {
			if ch := objs[i+1].MinSize().Height; ch > rowH {
				rowH = ch
			}
		}
		objs[i].Move(fyne.NewPos(0, y+((rowH-objs[i].MinSize().Height)/2)))
		objs[i].Resize(objs[i].MinSize())
		if i+1 < len(objs) {
			objs[i+1].Move(fyne.NewPos(labelW+gap, y))
			objs[i+1].Resize(fyne.NewSize(size.Width-labelW-gap, rowH))
		}
		y += rowH + 8
	}
}
