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
	"encoding/json"
	"fmt"
	"image/color"
	"io"
	"os"
	"sort"
	"strings"

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

const version = "v0.1"

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
		container.NewTabItem("Bar", barTab(&cfg, w)),
		container.NewTabItem("Hyprland", hyprTab(&cfg, w)),
		container.NewTabItem("Keys", keybindTab(&cfg, w)),
		container.NewTabItem("About", aboutTab(&cfg, w)),
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

	flavors := []string{"Mocha", "Macchiato", "Frappé", "Latte"}
	flavorKey := map[string]string{"Mocha": "mocha", "Macchiato": "macchiato", "Frappé": "frappe", "Latte": "latte"}
	keyFlavor := map[string]string{"mocha": "Mocha", "macchiato": "Macchiato", "frappe": "Frappé", "latte": "Latte"}
	palette := widget.NewSelect(flavors, func(s string) {
		cfg.Flavor = flavorKey[s]
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	})
	palette.SetSelected(keyFlavor[cfg.Flavor])
	paletteCard := widget.NewCard("Palette", "Catppuccin flavor — your accent stays on top", palette)

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.Flavor = d.Flavor
		palette.SetSelected(keyFlavor[d.Flavor])
		applyAccent(hexToColor(d.Accent))
	})

	body := container.NewVBox(accentCard, paletteCard, hintText("Applies instantly — safe, can’t break anything."))
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}

// ── Bar tab: layout, look, and per-widget visibility (all live) ──────────
func barTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	save := func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}

	style := widget.NewRadioGroup([]string{"Islands (floating)", "Classic (topbar)"}, func(s string) {
		if s == "Classic (topbar)" {
			cfg.BarStyle = "classic"
		} else {
			cfg.BarStyle = "islands"
		}
		save()
	})
	style.Horizontal = true

	posDisp := map[string]string{"top": "Top", "left": "Left", "right": "Right"}
	posKey := map[string]string{"Top": "top", "Left": "left", "Right": "right"}
	position := widget.NewRadioGroup([]string{"Top", "Left", "Right"}, func(s string) {
		cfg.BarPosition = posKey[s]
		save()
	})
	position.Horizontal = true

	opVal := widget.NewLabel("")
	op := widget.NewSlider(0.4, 1.0)
	op.Step = 0.02
	op.OnChanged = func(v float64) {
		cfg.BarOpacity = v
		opVal.SetText(fmt.Sprintf("%.0f%%", v*100))
		save()
	}

	clock := widget.NewCheck("24-hour clock", func(b bool) { cfg.Clock24h = b; save() })
	upd := widget.NewCheck("Update count", func(b bool) { cfg.ShowUpdates = b; save() })
	tmp := widget.NewCheck("Temperature warning", func(b bool) { cfg.ShowTemp = b; save() })
	bat := widget.NewCheck("Battery", func(b bool) { cfg.ShowBattery = b; save() })
	rec := widget.NewCheck("Recording indicator", func(b bool) { cfg.ShowRecording = b; save() })

	sync := func() {
		if cfg.BarStyle == "classic" {
			style.SetSelected("Classic (topbar)")
		} else {
			style.SetSelected("Islands (floating)")
		}
		position.SetSelected(posDisp[cfg.BarPosition])
		op.SetValue(cfg.BarOpacity)
		opVal.SetText(fmt.Sprintf("%.0f%%", cfg.BarOpacity*100))
		clock.SetChecked(cfg.Clock24h)
		upd.SetChecked(cfg.ShowUpdates)
		tmp.SetChecked(cfg.ShowTemp)
		bat.SetChecked(cfg.ShowBattery)
		rec.SetChecked(cfg.ShowRecording)
	}
	sync()

	lookCard := widget.NewCard("Layout & look", "", container.NewVBox(
		container.New(&labeledGrid{},
			widget.NewLabel("Edge"), position,
			widget.NewLabel("Style"), style,
			widget.NewLabel("Opacity"), sliderRow(op, opVal),
		),
		clock,
	))
	widgetsCard := widget.NewCard("Widgets", "Show or hide bar items",
		container.NewVBox(upd, tmp, bat, rec))

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.BarStyle = d.BarStyle
		cfg.BarPosition = d.BarPosition
		cfg.BarOpacity = d.BarOpacity
		cfg.Clock24h = d.Clock24h
		cfg.ShowUpdates = d.ShowUpdates
		cfg.ShowTemp = d.ShowTemp
		cfg.ShowBattery = d.ShowBattery
		cfg.ShowRecording = d.ShowRecording
		sync()
		save()
	})

	body := container.NewVBox(lookCard, widgetsCard, hintText("Bar changes apply instantly."))
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}

// ── Hyprland tab: hard changes behind Apply + reset ──────────────────────
func hyprTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	h := &cfg.Hypr
	var syncs []func()

	// intRow: a labelled integer slider that writes back to a field.
	intRow := func(label string, min, max float64, suffix string, get func() int, set func(int)) (fyne.CanvasObject, fyne.CanvasObject) {
		val := widget.NewLabel("")
		s := widget.NewSlider(min, max)
		s.Step = 1
		s.OnChanged = func(v float64) { set(int(v)); val.SetText(fmt.Sprintf("%d%s", int(v), suffix)) }
		syncs = append(syncs, func() { s.SetValue(float64(get())); val.SetText(fmt.Sprintf("%d%s", get(), suffix)) })
		return widget.NewLabel(label), sliderRow(s, val)
	}
	pctRow := func(label string, get func() float64, set func(float64)) (fyne.CanvasObject, fyne.CanvasObject) {
		val := widget.NewLabel("")
		s := widget.NewSlider(0.5, 1.0)
		s.Step = 0.01
		s.OnChanged = func(v float64) { set(v); val.SetText(fmt.Sprintf("%.0f%%", v*100)) }
		syncs = append(syncs, func() { s.SetValue(get()); val.SetText(fmt.Sprintf("%.0f%%", get()*100)) })
		return widget.NewLabel(label), sliderRow(s, val)
	}
	check := func(label string, get func() bool, set func(bool)) *widget.Check {
		c := widget.NewCheck(label, func(b bool) { set(b) })
		syncs = append(syncs, func() { c.SetChecked(get()) })
		return c
	}

	giL, giC := intRow("Gaps inner", 0, 30, "", func() int { return h.GapsIn }, func(v int) { h.GapsIn = v })
	goL, goC := intRow("Gaps outer", 0, 40, "", func() int { return h.GapsOut }, func(v int) { h.GapsOut = v })
	bsL, bsC := intRow("Border size", 0, 6, " px", func() int { return h.BorderSize }, func(v int) { h.BorderSize = v })
	rL, rC := intRow("Rounding", 0, 20, " px", func() int { return h.Rounding }, func(v int) { h.Rounding = v })
	aL, aC := pctRow("Active opacity", func() float64 { return h.ActiveOpacity }, func(v float64) { h.ActiveOpacity = v })
	iL, iC := pctRow("Inactive opacity", func() float64 { return h.InactiveOpacity }, func(v float64) { h.InactiveOpacity = v })
	blL, blC := intRow("Blur size", 0, 12, "", func() int { return h.BlurSize }, func(v int) { h.BlurSize = v })

	blurEn := check("Blur", func() bool { return h.BlurEnabled }, func(b bool) { h.BlurEnabled = b })
	shadowEn := check("Window shadows", func() bool { return h.ShadowEnabled }, func(b bool) { h.ShadowEnabled = b })
	animEn := check("Animations", func() bool { return h.AnimEnabled }, func(b bool) { h.AnimEnabled = b })
	borderOv := check("Custom border colors (replaces the gradient)", func() bool { return h.BorderOverride }, func(b bool) { h.BorderOverride = b })

	baSw := canvas.NewRectangle(hexToColor(h.BorderActive))
	baSw.SetMinSize(fyne.NewSize(26, 26))
	baSw.CornerRadius = 6
	biSw := canvas.NewRectangle(hexToColor(h.BorderInactive))
	biSw.SetMinSize(fyne.NewSize(26, 26))
	biSw.CornerRadius = 6
	syncs = append(syncs, func() {
		baSw.FillColor = hexToColor(h.BorderActive)
		baSw.Refresh()
		biSw.FillColor = hexToColor(h.BorderInactive)
		biSw.Refresh()
	})
	baBtn := widget.NewButton("Active…", func() {
		dialog.NewColorPicker("Active border", "", func(c color.Color) { h.BorderActive = colorToHex(c); baSw.FillColor = c; baSw.Refresh() }, w).Show()
	})
	biBtn := widget.NewButton("Inactive…", func() {
		dialog.NewColorPicker("Inactive border", "", func(c color.Color) { h.BorderInactive = colorToHex(c); biSw.FillColor = c; biSw.Refresh() }, w).Show()
	})

	sync := func() {
		for _, f := range syncs {
			f()
		}
	}
	sync()

	layoutCard := widget.NewCard("Layout", "", container.New(&labeledGrid{}, giL, giC, goL, goC, bsL, bsC, rL, rC))
	decoCard := widget.NewCard("Opacity", "pairs with the global blur", container.New(&labeledGrid{}, aL, aC, iL, iC))
	fxCard := widget.NewCard("Effects", "", container.NewVBox(
		blurEn,
		container.New(&labeledGrid{}, blL, blC),
		shadowEn, animEn,
	))
	borderCard := widget.NewCard("Border colors", "off keeps the base gradient", container.NewVBox(
		borderOv,
		container.NewHBox(container.NewCenter(baSw), baBtn, container.NewCenter(biSw), biBtn),
	))

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

	body := container.NewVBox(warnBanner(), layoutCard, decoCard, fxCard, borderCard)
	return container.NewBorder(nil, footerApply(reset, apply), nil, nil, container.NewVScroll(body))
}

// normCombo canonicalises "SUPER SHIFT, Q" → "SHIFT+SUPER|Q" for comparison.
func normCombo(combo string) string {
	parts := strings.SplitN(combo, ",", 2)
	key := ""
	if len(parts) == 2 {
		key = strings.ToUpper(strings.TrimSpace(parts[1]))
	}
	var mods []string
	for _, t := range strings.Fields(parts[0]) {
		u := strings.ToUpper(t)
		if u == "CONTROL" {
			u = "CTRL"
		}
		mods = append(mods, u)
	}
	sort.Strings(mods)
	return strings.Join(mods, "+") + "|" + key
}

var modNames = []string{"SUPER", "SHIFT", "CTRL", "ALT"}
var modLabel = map[string]string{"SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "ALT": "Alt"}

func parseCombo(combo string) (map[string]bool, string) {
	m := map[string]bool{}
	key := ""
	parts := strings.SplitN(combo, ",", 2)
	if len(parts) == 2 {
		key = strings.TrimSpace(parts[1])
	}
	for _, t := range strings.Fields(parts[0]) {
		u := strings.ToUpper(t)
		if u == "CONTROL" {
			u = "CTRL"
		}
		m[u] = true
	}
	return m, key
}

// ── Keybinds tab: modifier chips + key + live conflict detection ─────────
func keybindTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	// system shortcuts NOT in the editable set — warn if a bind collides
	reserved := map[string]string{
		normCombo("SUPER, Tab"): "cycle windows", normCombo("SUPER, B"): "wallpaper",
		normCombo("SUPER SHIFT, B"): "random wallpaper", normCombo("ALT, S"): "screenshot",
		normCombo("ALT, D"): "full screenshot", normCombo("SUPER, 1"): "workspace 1",
		normCombo("SUPER, 2"): "workspace 2", normCombo("SUPER, 3"): "workspace 3",
		normCombo("SUPER, 4"): "workspace 4",
	}

	checks := map[string]map[string]*widget.Check{}
	keys := map[string]*widget.Entry{}
	warn := widget.NewLabel("")
	warn.Importance = widget.WarningImportance
	warn.Wrapping = fyne.TextWrapWord
	ready := false

	refresh := func() {
		if !ready {
			return
		}
		byNorm := map[string][]string{}
		for _, id := range keybindOrder {
			var mods []string
			for _, mn := range modNames {
				if checks[id][mn].Checked {
					mods = append(mods, mn)
				}
			}
			key := strings.TrimSpace(keys[id].Text)
			kb := cfg.Keybinds[id]
			kb.Combo = strings.Join(mods, " ") + ", " + key
			cfg.Keybinds[id] = kb
			if key != "" {
				n := normCombo(kb.Combo)
				byNorm[n] = append(byNorm[n], kb.Label)
			}
		}
		var msgs []string
		for n, labels := range byNorm {
			if len(labels) > 1 {
				msgs = append(msgs, strings.Join(labels, " & ")+" share a shortcut")
			} else if sys, ok := reserved[n]; ok {
				msgs = append(msgs, labels[0]+" clashes with “"+sys+"”")
			}
		}
		sort.Strings(msgs)
		if len(msgs) > 0 {
			warn.SetText("⚠  " + strings.Join(msgs, " · "))
		} else {
			warn.SetText("")
		}
	}

	rowsUI := []fyne.CanvasObject{}
	for _, id := range keybindOrder {
		kb := cfg.Keybinds[id]
		m, key := parseCombo(kb.Combo)

		keyEntry := widget.NewEntry()
		keyEntry.SetText(key)
		keyEntry.SetPlaceHolder("key")
		keyEntry.OnChanged = func(string) { refresh() }
		keys[id] = keyEntry

		checks[id] = map[string]*widget.Check{}
		modRow := []fyne.CanvasObject{}
		for _, mn := range modNames {
			c := widget.NewCheck(modLabel[mn], func(bool) { refresh() })
			c.SetChecked(m[mn])
			checks[id][mn] = c
			modRow = append(modRow, c)
		}

		rowsUI = append(rowsUI,
			container.NewBorder(nil, nil,
				widget.NewLabelWithStyle(kb.Label, fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
				container.NewGridWrap(fyne.NewSize(90, 34), keyEntry)),
			container.NewHBox(modRow...),
			widget.NewSeparator(),
		)
	}
	ready = true
	refresh()

	card := widget.NewCard("Shortcuts", "Modifiers + a key — no Hyprland syntax to remember", container.NewVBox(rowsUI...))

	apply := widget.NewButton("Apply", func() {
		refresh()
		if err := saveApply(cfg, w); err == nil {
			dialog.ShowInformation("Applied", "Keybinds reloaded.", w)
		}
	})
	apply.Importance = widget.HighImportance
	reset := resetButton(func() {
		for _, id := range keybindOrder {
			m, key := parseCombo(cfg.Keybinds[id].Default)
			for _, mn := range modNames {
				checks[id][mn].SetChecked(m[mn])
			}
			keys[id].SetText(key)
		}
		refresh()
		saveApply(cfg, w)
	})

	body := container.NewVBox(warnBanner(), warn, card)
	return container.NewBorder(nil, footerApply(reset, apply), nil, nil, container.NewVScroll(body))
}

// ── About tab: config import/export/reset + version ─────────────────────
func aboutTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	export := widget.NewButton("Export…", func() {
		d := dialog.NewFileSave(func(wc fyne.URIWriteCloser, err error) {
			if err != nil || wc == nil {
				return
			}
			defer wc.Close()
			data, _ := json.MarshalIndent(*cfg, "", "  ")
			if _, err := wc.Write(append(data, '\n')); err != nil {
				dialog.ShowError(err, w)
			}
		}, w)
		d.SetFileName("moonlit-config.json")
		d.Show()
	})
	imp := widget.NewButton("Import…", func() {
		dialog.NewFileOpen(func(rc fyne.URIReadCloser, err error) {
			if err != nil || rc == nil {
				return
			}
			defer rc.Close()
			data, e := io.ReadAll(rc)
			if e != nil {
				dialog.ShowError(e, w)
				return
			}
			var nc Config
			if e := json.Unmarshal(data, &nc); e != nil {
				dialog.ShowError(fmt.Errorf("not a valid config: %v", e), w)
				return
			}
			*cfg = nc
			if e := saveConfig(*cfg); e != nil {
				dialog.ShowError(e, w)
				return
			}
			_ = applyHypr(*cfg)
			dialog.ShowInformation("Imported", "Config imported and applied. Reopen Moonlit Settings to refresh the controls.", w)
		}, w).Show()
	})
	resetAll := widget.NewButton("Reset everything", func() {
		dialog.ShowConfirm("Reset everything", "Restore all settings to defaults?", func(ok bool) {
			if !ok {
				return
			}
			*cfg = defaultConfig()
			if e := saveConfig(*cfg); e != nil {
				dialog.ShowError(e, w)
				return
			}
			_ = applyHypr(*cfg)
			dialog.ShowInformation("Reset", "All settings restored. Reopen to refresh the controls.", w)
		}, w)
	})
	resetAll.Importance = widget.LowImportance

	cfgCard := widget.NewCard("Config", "Back up, move, or reset your settings", container.NewVBox(
		container.NewHBox(export, imp),
		hintText("Exports ~/.config/moonlit/config.json. Import replaces it and applies."),
		resetAll,
	))

	repo := canvas.NewText("github.com/Fi3w0/Moonlit-shell", hexToColor(cMauve))
	repo.TextStyle = fyne.TextStyle{Monospace: true}
	aboutCard := widget.NewCard("About", "", container.NewVBox(
		widget.NewLabelWithStyle("Moonlit Shell  ·  settings "+version, fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		widget.NewLabel("A hand-crafted Hyprland + Quickshell desktop."),
		repo,
		hintText("Made with 🌙"),
	))

	return container.NewVScroll(container.NewPadded(container.NewVBox(cfgCard, aboutCard)))
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
