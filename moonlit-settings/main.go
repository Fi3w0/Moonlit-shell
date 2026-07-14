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
	_ "embed"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"io"
	"os"
	"os/exec"
	"path/filepath"
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

//go:embed icon.png
var iconBytes []byte

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
	a.SetIcon(fyne.NewStaticResource("moonlit-settings.png", iconBytes))
	a.Settings().SetTheme(moonlitTheme{})
	w := a.NewWindow("Moonlit Settings")
	w.SetIcon(fyne.NewStaticResource("moonlit-settings.png", iconBytes))

	cfg := loadConfig()

	w.SetContent(container.NewBorder(header(), nil, nil, nil, func() fyne.CanvasObject {
		if isFirstRun() {
			return wizardScreen(&cfg, w)
		}
		tabs := container.NewAppTabs(
			container.NewTabItem("Theme", themeTab(&cfg, w)),
			container.NewTabItem("Bar", barTab(&cfg, w)),
			container.NewTabItem("Notifications", notifTab(&cfg, w)),
			container.NewTabItem("Wallpapers", wallpaperTab(&cfg, w)),
			container.NewTabItem("Power", powerTab(&cfg, w)),
			container.NewTabItem("Hyprland", hyprTab(&cfg, w)),
			container.NewTabItem("Keys", keybindTab(&cfg, w)),
			container.NewTabItem("About", aboutTab(&cfg, w)),
		)
		tabs.SetTabLocation(container.TabLocationTop)
		return tabs
	}()))
	w.Resize(fyne.NewSize(500, 600))
	w.ShowAndRun()
}

// ── First-run wizard ─────────────────────────────────────────────────────
func wizardScreen(cfg *Config, w fyne.Window) fyne.CanvasObject {
	swatch := canvas.NewCircle(hexToColor(cfg.Accent))
	swatch.StrokeColor = hexToColor(cSurface1)
	swatch.StrokeWidth = 1
	swatchBox := container.NewGridWrap(fyne.NewSize(44, 44), swatch)
	hexLabel := canvas.NewText(cfg.Accent, hexToColor(cText))
	hexLabel.TextStyle = fyne.TextStyle{Monospace: true}
	hexLabel.TextSize = 15

	flavors := []string{"Mocha", "Macchiato", "Frappé", "Latte"}
	flavorKey := map[string]string{"Mocha": "mocha", "Macchiato": "macchiato", "Frappé": "frappe", "Latte": "latte"}
	palette := widget.NewSelect(flavors, func(s string) { cfg.Flavor = flavorKey[s] })

	style := widget.NewRadioGroup([]string{"Islands (floating pills)", "Classic (solid bar)"}, func(s string) {
		if s == "Classic (solid bar)" {
			cfg.BarStyle = "classic"
		} else {
			cfg.BarStyle = "islands"
		}
	})
	style.Horizontal = true

	pos := widget.NewRadioGroup([]string{"Top", "Left", "Right"}, func(s string) {
		cfg.BarPosition = map[string]string{"Top": "top", "Left": "left", "Right": "right"}[s]
	})
	pos.Horizontal = true

	pickAccent := widget.NewButton("Pick accent color", func() {
		p := dialog.NewColorPicker("Accent color", "", func(c color.Color) {
			cfg.Accent = colorToHex(c)
			swatch.FillColor = c
			swatch.Refresh()
			hexLabel.Text = cfg.Accent
			hexLabel.Refresh()
		}, w)
		p.Advanced = true
		p.Show()
	})
	pickAccent.Importance = widget.HighImportance

	getStarted := widget.NewButton("Get Started", func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
			return
		}
		markFirstRunDone()
		// Re-render with tabs
		w.SetContent(container.NewBorder(header(), nil, nil, nil,
			container.NewAppTabs(
				container.NewTabItem("Theme", themeTab(cfg, w)),
				container.NewTabItem("Bar", barTab(cfg, w)),
				container.NewTabItem("Notifications", notifTab(cfg, w)),
				container.NewTabItem("Wallpapers", wallpaperTab(cfg, w)),
				container.NewTabItem("Power", powerTab(cfg, w)),
				container.NewTabItem("Hyprland", hyprTab(cfg, w)),
				container.NewTabItem("Keys", keybindTab(cfg, w)),
				container.NewTabItem("About", aboutTab(cfg, w)),
			)))
	})
	getStarted.Importance = widget.SuccessImportance

	welcome := widget.NewLabelWithStyle("Welcome to Moonlit Shell", fyne.TextAlignCenter, fyne.TextStyle{Bold: true})
	welcomeSub := widget.NewLabel("Set up the basics — everything can be changed later.")
	welcomeSub.Alignment = fyne.TextAlignCenter

	accentRow := container.NewHBox(container.NewCenter(swatchBox), container.NewCenter(hexLabel), container.NewCenter(pickAccent))
	paletteRow := widget.NewCard("Palette", "Catppuccin flavor (your accent stays on top)", palette)
	barRow := widget.NewCard("Bar style", "Floating pill islands or a classic solid bar", container.NewVBox(style, pos))

	return container.NewPadded(container.NewVBox(
		container.NewCenter(welcome),
		container.NewCenter(welcomeSub),
		widget.NewSeparator(),
		widget.NewCard("Accent", "The signature color across your desktop", accentRow),
		paletteRow,
		barRow,
		widget.NewSeparator(),
		container.NewCenter(getStarted),
		hintText("You can change everything later in the settings tabs."),
	))
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

// ── Notifications tab: toast duration, max visible, position ────────────
func notifTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	save := func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}

	durVal := widget.NewLabel("")
	dur := widget.NewSlider(1000, 10000)
	dur.Step = 200
	dur.OnChanged = func(v float64) {
		cfg.ToastDuration = int(v)
		durVal.SetText(fmt.Sprintf("%.1fs", v/1000))
		save()
	}

	maxVal := widget.NewLabel("")
	maxS := widget.NewSlider(1, 10)
	maxS.Step = 1
	maxS.OnChanged = func(v float64) {
		cfg.MaxToasts = int(v)
		maxVal.SetText(fmt.Sprintf("%d", int(v)))
		save()
	}

	posOpts := []string{"Auto (follows bar)", "Top-right", "Top-left", "Bottom-right", "Bottom-left"}
	posKeys := map[string]string{"Auto (follows bar)": "auto", "Top-right": "top-right", "Top-left": "top-left", "Bottom-right": "bottom-right", "Bottom-left": "bottom-left"}
	var toastPosKey = map[string]string{"auto": "Auto (follows bar)", "top-right": "Top-right", "top-left": "Top-left", "bottom-right": "Bottom-right", "bottom-left": "Bottom-left"}

	pos := widget.NewSelect(posOpts, func(s string) {
		cfg.ToastPosition = posKeys[s]
		save()
	})

	sync := func() {
		dur.SetValue(float64(cfg.ToastDuration))
		durVal.SetText(fmt.Sprintf("%.1fs", float64(cfg.ToastDuration)/1000))
		maxS.SetValue(float64(cfg.MaxToasts))
		maxVal.SetText(fmt.Sprintf("%d", cfg.MaxToasts))
		pos.SetSelected(toastPosKey[cfg.ToastPosition])
	}
	sync()

	durCard := widget.NewCard("Duration", "How long each notification stays on screen", container.New(&labeledGrid{},
		widget.NewLabel("Toast timeout"), sliderRow(dur, durVal)))
	maxCard := widget.NewCard("Max visible", "Cap how many toasts appear at once (oldest dismissed first)", container.New(&labeledGrid{},
		widget.NewLabel("Max toasts"), sliderRow(maxS, maxVal)))
	posCard := widget.NewCard("Position", "Which corner the notification stack anchors to", pos)

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.ToastDuration = d.ToastDuration
		cfg.MaxToasts = d.MaxToasts
		cfg.ToastPosition = d.ToastPosition
		sync()
		save()
	})

	body := container.NewVBox(durCard, maxCard, posCard, hintText("Notifications changes apply instantly."))
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}

// ── Wallpapers tab: directory path + slideshow interval ──────────────────
func wallpaperTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	save := func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}

	dirEntry := widget.NewEntry()
	dirEntry.SetText(cfg.WallpaperDir)
	dirEntry.SetPlaceHolder("~/Pictures/Wallpapers")
	dirEntry.OnChanged = func(s string) {
		cfg.WallpaperDir = s
		save()
	}

	dirCard := widget.NewCard("Wallpaper directory", "Where your wallpaper images live", container.NewVBox(
		dirEntry,
		widget.NewButton("Browse…", func() {
			dialog.NewFolderOpen(func(lu fyne.ListableURI, err error) {
				if err != nil || lu == nil {
					return
				}
				dirEntry.SetText(lu.Path())
			}, w).Show()
		}),
		hintText("Use ~ for your home directory (e.g. ~/Pictures/Wallpapers). Changes apply when you reopen the wallpaper panel."),
	))

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.WallpaperDir = d.WallpaperDir
		dirEntry.SetText(d.WallpaperDir)
		save()
	})

	body := container.NewVBox(dirCard)
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}

// ── Power tab: CPU governor toggle ───────────────────────────────────────
func powerTab(cfg *Config, w fyne.Window) fyne.CanvasObject {
	save := func() {
		if err := saveConfig(*cfg); err != nil {
			dialog.ShowError(err, w)
		}
	}
	applyGov := func(gov string) {
		// Write to all cpus concurrently
		cpus, _ := filepath.Glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor")
		if len(cpus) == 0 {
			return
		}
		for _, p := range cpus {
			os.WriteFile(p, []byte(gov), 0o222)
		}
	}

	labelToKey := map[string]string{
		"Power save": "powersave", "Balanced (schedutil)": "schedutil",
		"Performance": "performance", "On-demand": "ondemand", "Conservative": "conservative",
	}
	keyToLabel := map[string]string{}
	for l, k := range labelToKey {
		keyToLabel[k] = l
	}

	// Discover available governors
	avail := []string{}
	if data, err := os.ReadFile("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"); err == nil {
		for _, g := range strings.Fields(string(data)) {
			if label, ok := keyToLabel[g]; ok {
				avail = append(avail, label)
			}
		}
	}
	if len(avail) == 0 {
		avail = []string{"Power save", "Balanced (schedutil)", "Performance"}
	}

	sel := widget.NewSelect(avail, func(s string) {
		gov := labelToKey[s]
		cfg.PowerProfile = gov
		save()
		applyGov(gov)
	})
	if label, ok := keyToLabel[cfg.PowerProfile]; ok {
		sel.SetSelected(label)
	} else if len(avail) > 0 {
		sel.SetSelected(avail[0])
	}

	govCard := widget.NewCard("CPU governor", "Controls CPU frequency scaling behavior", sel)
	descCard := widget.NewCard("What they do", "", container.NewVBox(
		hintText("Power save — lowest clock speed, best battery life"),
		hintText("Balanced — scales up only when needed (default)"),
		hintText("Performance — locks at max frequency, more heat"),
	))

	reset := resetButton(func() {
		d := defaultConfig()
		cfg.PowerProfile = d.PowerProfile
		if label, ok := keyToLabel[d.PowerProfile]; ok {
			sel.SetSelected(label)
		}
		save()
		applyGov(d.PowerProfile)
	})

	body := container.NewVBox(govCard, descCard, hintText("Changes apply immediately. Dropped on reboot — re-apply from this tab or set a systemd service to persist."))
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

// ── About tab: config import/export/reset + version + health check ────
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
		hintText("Auto-backup: every Apply snapshots config.json to ~/.config/moonlit/backups/ (keeps last 50)."),
		resetAll,
	))

	health := widget.NewButton("Run health check", func() {
		home, _ := os.UserHomeDir()
		doc := filepath.Join(home, "moonlit-shell", "scripts", "moonlit-doctor")
		if _, err := os.Stat(doc); os.IsNotExist(err) {
			exe, _ := os.Executable()
			doc = filepath.Join(filepath.Dir(exe), "..", "..", "scripts", "moonlit-doctor")
		}
		cmd := exec.Command("kitty", "-e", doc)
		if err := cmd.Start(); err != nil {
			dialog.ShowError(fmt.Errorf("could not launch health check: %v", err), w)
		}
	})
	health.Importance = widget.MediumImportance
	healthCard := widget.NewCard("Diagnostics", "Check that everything is wired up correctly", health)

	screenshot := widget.NewButton("Export as PNG", func() {
		dialog.NewFileSave(func(wc fyne.URIWriteCloser, err error) {
			if err != nil || wc == nil {
				return
			}
			defer wc.Close()
			img := renderCard(cfg)
			if err := png.Encode(wc, img); err != nil {
				dialog.ShowError(err, w)
			} else {
				dialog.ShowInformation("Exported", "Config card saved as PNG.", w)
			}
		}, w).Show()
	})
	screenshot.Importance = widget.MediumImportance
	shareCard := widget.NewCard("Share", "Export a pretty config card to show off your rice",
		container.NewVBox(screenshot, hintText("Saves a Catppuccin-themed config summary card as PNG.")))

	repo := canvas.NewText("github.com/Fi3w0/Moonlit-shell", hexToColor(cMauve))
	repo.TextStyle = fyne.TextStyle{Monospace: true}
	aboutCard := widget.NewCard("About", "", container.NewVBox(
		widget.NewLabelWithStyle("Moonlit Shell  ·  settings "+version, fyne.TextAlignLeading, fyne.TextStyle{Bold: true}),
		widget.NewLabel("A hand-crafted Hyprland + Quickshell desktop."),
		repo,
		hintText("Made with 🌙"),
	))

	return container.NewVScroll(container.NewPadded(container.NewVBox(cfgCard, healthCard, shareCard, aboutCard)))
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

// ── Config card renderer for PNG export ──────────────────────────────────
// Renders a Catppuccin Mocha-themed summary card as an 800×500 image.

var cardPalette = map[string]*image.Uniform{
	"base":     image.NewUniform(hexToColor("#1e1e2e")),
	"mantle":   image.NewUniform(hexToColor("#181825")),
	"surface0": image.NewUniform(hexToColor("#313244")),
	"surface1": image.NewUniform(hexToColor("#45475a")),
	"mauve":    image.NewUniform(hexToColor("#cba6f7")),
	"text":     image.NewUniform(hexToColor("#cdd6f4")),
	"subtext0": image.NewUniform(hexToColor("#a6adc8")),
	"overlay0": image.NewUniform(hexToColor("#6c7086")),
	"green":    image.NewUniform(hexToColor("#a6e3a1")),
	"maroon":   image.NewUniform(hexToColor("#eba0ac")),
}

func fillRect(img *image.RGBA, x, y, w, h int, c *image.Uniform) {
	draw.Draw(img, image.Rect(x, y, x+w, y+h), c, image.Point{}, draw.Src)
}

func cardText(img *image.RGBA, x, y int, s string, c *image.Uniform, size int) {
	// Simple 6×9 block font — renders ASCII letters/digits/symbols as small
	// pixel blocks. Lowercase = uppercase, missing glyphs render as blank.
	for i, ch := range s {
		drawGlyph(img, x+i*(size+1), y, ch, c, size)
	}
}

// drawGlyph renders a single character at (x,y) using a 5×8 pixel font
// scaled up to the requested size. The glyph data is a 5-byte bitmap where
// each byte = one row (top to bottom), each bit = on/off (msb = left).
var glyphs = map[rune][]byte{
	'A': {0x7E, 0x11, 0x11, 0x11, 0x7E, 0x00, 0x00, 0x00},
	'B': {0x7F, 0x49, 0x49, 0x49, 0x36, 0x00, 0x00, 0x00},
	'C': {0x3E, 0x41, 0x41, 0x41, 0x22, 0x00, 0x00, 0x00},
	'D': {0x7F, 0x41, 0x41, 0x41, 0x3E, 0x00, 0x00, 0x00},
	'E': {0x7F, 0x49, 0x49, 0x49, 0x41, 0x00, 0x00, 0x00},
	'F': {0x7F, 0x09, 0x09, 0x09, 0x01, 0x00, 0x00, 0x00},
	'G': {0x3E, 0x41, 0x49, 0x49, 0x7A, 0x00, 0x00, 0x00},
	'H': {0x7F, 0x08, 0x08, 0x08, 0x7F, 0x00, 0x00, 0x00},
	'I': {0x41, 0x41, 0x7F, 0x41, 0x41, 0x00, 0x00, 0x00},
	'J': {0x20, 0x40, 0x41, 0x3F, 0x01, 0x00, 0x00, 0x00},
	'K': {0x7F, 0x08, 0x14, 0x22, 0x41, 0x00, 0x00, 0x00},
	'L': {0x7F, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00},
	'M': {0x7F, 0x02, 0x0C, 0x02, 0x7F, 0x00, 0x00, 0x00},
	'N': {0x7F, 0x04, 0x08, 0x10, 0x7F, 0x00, 0x00, 0x00},
	'O': {0x3E, 0x41, 0x41, 0x41, 0x3E, 0x00, 0x00, 0x00},
	'P': {0x7F, 0x09, 0x09, 0x09, 0x06, 0x00, 0x00, 0x00},
	'Q': {0x3E, 0x41, 0x51, 0x21, 0x5E, 0x00, 0x00, 0x00},
	'R': {0x7F, 0x09, 0x19, 0x29, 0x46, 0x00, 0x00, 0x00},
	'S': {0x26, 0x49, 0x49, 0x49, 0x32, 0x00, 0x00, 0x00},
	'T': {0x01, 0x01, 0x7F, 0x01, 0x01, 0x00, 0x00, 0x00},
	'U': {0x3F, 0x40, 0x40, 0x40, 0x3F, 0x00, 0x00, 0x00},
	'V': {0x1F, 0x20, 0x40, 0x20, 0x1F, 0x00, 0x00, 0x00},
	'W': {0x3F, 0x40, 0x38, 0x40, 0x3F, 0x00, 0x00, 0x00},
	'X': {0x63, 0x14, 0x08, 0x14, 0x63, 0x00, 0x00, 0x00},
	'Y': {0x07, 0x08, 0x70, 0x08, 0x07, 0x00, 0x00, 0x00},
	'Z': {0x61, 0x51, 0x49, 0x45, 0x43, 0x00, 0x00, 0x00},
	'0': {0x3E, 0x51, 0x49, 0x45, 0x3E, 0x00, 0x00, 0x00},
	'1': {0x42, 0x42, 0x7F, 0x40, 0x40, 0x00, 0x00, 0x00},
	'2': {0x62, 0x51, 0x49, 0x49, 0x46, 0x00, 0x00, 0x00},
	'3': {0x22, 0x41, 0x49, 0x49, 0x36, 0x00, 0x00, 0x00},
	'4': {0x18, 0x14, 0x12, 0x7F, 0x10, 0x00, 0x00, 0x00},
	'5': {0x27, 0x45, 0x45, 0x45, 0x39, 0x00, 0x00, 0x00},
	'6': {0x3E, 0x49, 0x49, 0x49, 0x30, 0x00, 0x00, 0x00},
	'7': {0x01, 0x71, 0x09, 0x05, 0x03, 0x00, 0x00, 0x00},
	'8': {0x36, 0x49, 0x49, 0x49, 0x36, 0x00, 0x00, 0x00},
	'9': {0x06, 0x49, 0x49, 0x29, 0x1E, 0x00, 0x00, 0x00},
	'.': {0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00},
	',': {0x00, 0x00, 0x40, 0x20, 0x00, 0x00, 0x00, 0x00},
	':': {0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00},
	'/': {0x20, 0x10, 0x08, 0x04, 0x02, 0x00, 0x00, 0x00},
	'#': {0x14, 0x7F, 0x14, 0x7F, 0x14, 0x00, 0x00, 0x00},
	'~': {0x08, 0x04, 0x08, 0x10, 0x08, 0x00, 0x00, 0x00},
	' ': {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
	'(': {0x1C, 0x22, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00},
	')': {0x00, 0x00, 0x41, 0x22, 0x1C, 0x00, 0x00, 0x00},
	'-': {0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x00, 0x00},
	'%': {0x43, 0x24, 0x18, 0x24, 0x43, 0x00, 0x00, 0x00},
	'x': {0x22, 0x14, 0x08, 0x14, 0x22, 0x00, 0x00, 0x00},
}

func drawGlyph(img *image.RGBA, x, y int, ch rune, c *image.Uniform, scale int) {
	g, ok := glyphs[ch]
	if !ok {
		if ch >= 'a' && ch <= 'z' {
			g = glyphs[ch-32] // lowercase → uppercase
		} else {
			return // unknown glyph
		}
	}
	for row := 0; row < 8; row++ {
		b := g[row]
		for col := 0; col < 5; col++ {
			if (b>>(4-col))&1 != 0 {
				fillRect(img, x+col*scale, y+row*scale, scale, scale, c)
			}
		}
	}
}

func renderCard(cfg *Config) image.Image {
	img := image.NewRGBA(image.Rect(0, 0, 720, 400))
	draw.Draw(img, img.Bounds(), cardPalette["base"], image.Point{}, draw.Src)

	// Corner radius effect: just draw a slightly smaller mantel rect
	fillRect(img, 18, 18, 684, 364, cardPalette["mantle"])

	// Title bar
	fillRect(img, 18, 18, 684, 52, cardPalette["surface0"])
	cardText(img, 38, 32, "MOONLIT SHELL", cardPalette["mauve"], 2)
	cardText(img, 38, 52, "config v0.1", cardPalette["overlay0"], 1)

	// Accent swatch
	fillRect(img, 620, 28, 68, 32, image.NewUniform(hexToColor(cfg.Accent)))

	// Body rows
	row := func(y int, label, value string) {
		cardText(img, 38, y, label, cardPalette["overlay0"], 1)
		cardText(img, 220, y, value, cardPalette["text"], 1)
	}

	row(88, "Accent", cfg.Accent)
	row(106, "Flavor", cfg.Flavor)
	row(124, "Bar style", cfg.BarStyle+"  ·  "+cfg.BarPosition)
	row(142, "Bar opacity", fmt.Sprintf("%.0f%%", cfg.BarOpacity*100))
	row(160, "Clock", map[bool]string{true: "24h", false: "12h"}[cfg.Clock24h])
	row(178, "Rounding", fmt.Sprintf("%dpx", cfg.Hypr.Rounding))
	row(196, "Opacity", fmt.Sprintf("active %.0f%%  ·  inactive %.0f%%", cfg.Hypr.ActiveOpacity*100, cfg.Hypr.InactiveOpacity*100))
	row(214, "Gaps", fmt.Sprintf("in %d  ·  out %d", cfg.Hypr.GapsIn, cfg.Hypr.GapsOut))
	row(232, "Border", fmt.Sprintf("%dpx", cfg.Hypr.BorderSize))
	row(250, "Blur", map[bool]string{true: "on (" + fmt.Sprintf("%d", cfg.Hypr.BlurSize) + ")", false: "off"}[cfg.Hypr.BlurEnabled])
	row(268, "Animations", map[bool]string{true: "on", false: "off"}[cfg.Hypr.AnimEnabled])
	row(286, "Toast duration", fmt.Sprintf("%.1fs", float64(cfg.ToastDuration)/1000))
	row(304, "Max toasts", fmt.Sprintf("%d", cfg.MaxToasts))
	row(322, "Power profile", cfg.PowerProfile)

	// Keybinds section
	cardText(img, 38, 354, "KEYBINDS", cardPalette["subtext0"], 1)
	keys := []string{"terminal", "launcher", "close", "fullscreen"}
	x := 38
	for _, id := range keys {
		if kb, ok := cfg.Keybinds[id]; ok {
			txt := kb.Label + "  " + kb.Combo
			cardText(img, x, 372, txt, cardPalette["text"], 1)
			x += len(txt)*7 + 30
		}
	}

	// Footer
	cardText(img, 38, 388, "github.com/Fi3w0/Moonlit-shell", cardPalette["overlay0"], 1)

	return img
}
