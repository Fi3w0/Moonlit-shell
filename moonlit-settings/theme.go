package main

import (
	"image/color"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

// moonlitTheme is a Catppuccin Mocha theme for Fyne, mauve-forward to match
// the shell. The window reads as frosted glass because a Hyprland windowrule
// gives it opacity over the global blur — so here we just keep it dark and
// intentional. Font/icon/size fall through to Fyne defaults.
type moonlitTheme struct{}

var _ fyne.Theme = moonlitTheme{}

func hx(s string) color.Color { return hexToColor(s) }

func withAlpha(c color.Color, a uint8) color.Color {
	nc := color.NRGBAModel.Convert(c).(color.NRGBA)
	nc.A = a
	return nc
}

func (moonlitTheme) Color(name fyne.ThemeColorName, _ fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return hx("#1e1e2e") // base
	case theme.ColorNameForeground:
		return hx("#cdd6f4") // text
	case theme.ColorNameForegroundOnPrimary:
		return hx("#1e1e2e")
	case theme.ColorNamePrimary:
		return hx("#cba6f7") // mauve
	case theme.ColorNameButton:
		return hx("#313244") // surface0
	case theme.ColorNameDisabledButton:
		return hx("#252537")
	case theme.ColorNameInputBackground:
		return hx("#313244")
	case theme.ColorNameInputBorder:
		return hx("#45475a")
	case theme.ColorNameHover:
		return withAlpha(hx("#cba6f7"), 0x22)
	case theme.ColorNamePressed:
		return withAlpha(hx("#cba6f7"), 0x33)
	case theme.ColorNameSelection:
		return withAlpha(hx("#cba6f7"), 0x33)
	case theme.ColorNameFocus:
		return withAlpha(hx("#cba6f7"), 0x55)
	case theme.ColorNameSeparator:
		return hx("#313244")
	case theme.ColorNameMenuBackground:
		return hx("#181825") // mantle
	case theme.ColorNameOverlayBackground:
		return hx("#181825")
	case theme.ColorNameShadow:
		return withAlpha(hx("#11111b"), 0x66)
	case theme.ColorNamePlaceHolder, theme.ColorNameDisabled:
		return hx("#6c7086") // overlay
	case theme.ColorNameScrollBar:
		return withAlpha(hx("#45475a"), 0x99)
	case theme.ColorNameSuccess:
		return hx("#a6e3a1")
	case theme.ColorNameWarning:
		return hx("#f9e2af")
	case theme.ColorNameError:
		return hx("#f38ba8")
	default:
		return theme.DefaultTheme().Color(name, theme.VariantDark)
	}
}

func (moonlitTheme) Font(s fyne.TextStyle) fyne.Resource { return theme.DefaultTheme().Font(s) }
func (moonlitTheme) Icon(n fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(n)
}

func (moonlitTheme) Size(name fyne.ThemeSizeName) float32 {
	switch name {
	case theme.SizeNamePadding:
		return 6
	case theme.SizeNameInnerPadding:
		return 9
	case theme.SizeNameInputRadius, theme.SizeNameSelectionRadius:
		return 9
	default:
		return theme.DefaultTheme().Size(name)
	}
}
