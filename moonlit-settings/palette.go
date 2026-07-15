package main

import (
	"fmt"
	"image/color"
	"math"
)

// flavorRamps mirrors the neutral ramps in services/Config.qml (base…text).
// Full-palette wallust keeps a flavor's exact lightness/structure — so a light
// flavor stays light, a dark one stays dark — and only re-tints each slot's hue
// toward the wallpaper. That guarantees the result is always readable, never
// low-contrast mud, no matter what colors the wallpaper yields.
//
// Keep this in sync with the _flavors table in services/Config.qml.
var flavorRamps = map[string]map[string]string{
	"mocha": {
		"base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b",
		"surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
		"overlay0": "#6c7086", "overlay1": "#7f849c", "overlay2": "#9399b2",
		"subtext0": "#a6adc8", "subtext1": "#bac2de", "text": "#cdd6f4",
	},
	"macchiato": {
		"base": "#24273a", "mantle": "#1e2030", "crust": "#181926",
		"surface0": "#363a4f", "surface1": "#494d64", "surface2": "#5b6078",
		"overlay0": "#6e738d", "overlay1": "#8087a2", "overlay2": "#939ab7",
		"subtext0": "#a5adcb", "subtext1": "#b8c0e0", "text": "#cad3f5",
	},
	"frappe": {
		"base": "#303446", "mantle": "#292c3c", "crust": "#232634",
		"surface0": "#414559", "surface1": "#51576d", "surface2": "#626880",
		"overlay0": "#737994", "overlay1": "#838ba7", "overlay2": "#949cbb",
		"subtext0": "#a5adce", "subtext1": "#b5bfe2", "text": "#c6d0f5",
	},
	"latte": {
		"base": "#eff1f5", "mantle": "#e6e9ef", "crust": "#dce0e8",
		"surface0": "#ccd0da", "surface1": "#bcc0cc", "surface2": "#acb0be",
		"overlay0": "#9ca0b0", "overlay1": "#8c8fa1", "overlay2": "#7c7f93",
		"subtext0": "#6c6f85", "subtext1": "#5c5f77", "text": "#4c4f69",
	},
}

// rgbToHSL converts a color to hue (0-360), saturation and lightness (0-1).
func rgbToHSL(c color.Color) (h, s, l float64) {
	nc := color.NRGBAModel.Convert(c).(color.NRGBA)
	r, g, b := float64(nc.R)/255, float64(nc.G)/255, float64(nc.B)/255
	max := math.Max(r, math.Max(g, b))
	min := math.Min(r, math.Min(g, b))
	l = (max + min) / 2
	if max == min {
		return 0, 0, l // achromatic
	}
	d := max - min
	if l > 0.5 {
		s = d / (2 - max - min)
	} else {
		s = d / (max + min)
	}
	switch max {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	default:
		h = (r-g)/d + 4
	}
	return h * 60, s, l
}

// hslToHex is the inverse of rgbToHSL, formatted as "#rrggbb".
func hslToHex(h, s, l float64) string {
	h = math.Mod(math.Mod(h, 360)+360, 360) / 360
	var r, g, b float64
	if s == 0 {
		r, g, b = l, l, l
	} else {
		var q float64
		if l < 0.5 {
			q = l * (1 + s)
		} else {
			q = l + s - l*s
		}
		p := 2*l - q
		hue2 := func(t float64) float64 {
			if t < 0 {
				t += 1
			}
			if t > 1 {
				t -= 1
			}
			switch {
			case t < 1.0/6:
				return p + (q-p)*6*t
			case t < 1.0/2:
				return q
			case t < 2.0/3:
				return p + (q-p)*(2.0/3-t)*6
			default:
				return p
			}
		}
		r = hue2(h + 1.0/3)
		g = hue2(h)
		b = hue2(h - 1.0/3)
	}
	to8 := func(v float64) uint8 { return uint8(math.Round(math.Max(0, math.Min(1, v)) * 255)) }
	return fmt.Sprintf("#%02x%02x%02x", to8(r), to8(g), to8(b))
}

// tintedPalette rebuilds flavor's neutral ramp, swapping every slot's hue for
// tintHue and nudging saturation up a touch so the wallpaper actually shows,
// while preserving each slot's original lightness (the part that keeps text
// readable against surfaces). Falls back to mocha for an unknown flavor.
func tintedPalette(flavor string, tintHue float64) map[string]string {
	ramp, ok := flavorRamps[flavor]
	if !ok {
		ramp = flavorRamps["mocha"]
	}
	out := make(map[string]string, len(ramp))
	for slot, hex := range ramp {
		_, s, l := rgbToHSL(hexToColor(hex))
		// Keep the slot's own saturation feel (text is more tinted than base in
		// Catppuccin), boosted slightly and floored so even near-gray slots pick
		// up a hint of the wallpaper; capped so neutrals never go garish.
		ns := math.Min(0.5, math.Max(s*1.2, 0.06))
		out[slot] = hslToHex(tintHue, ns, l)
	}
	return out
}
