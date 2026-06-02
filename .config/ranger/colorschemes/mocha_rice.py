from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import bold, normal, default_colors

# Catppuccin Mocha — matched to the Quickshell palette (256-color approximations)
# text #cdd6f4≈189  mauve #cba6f7≈183  sky #89dceb≈117  green #a6e3a1≈151
# pink/red #f38ba8≈211  yellow #f9e2af≈223  surface1 #45475a≈238
class Scheme(ColorScheme):
    def use(self, context):
        fg, bg, attr = 189, -1, normal

        if context.reset:
            return default_colors

        elif context.in_browser:
            # selection: subtle surface highlight with mauve text
            if context.selected:
                bg = 238
                fg = 183
                attr = bold

            if context.directory:
                if not context.selected:
                    fg = 183            # mauve
                attr |= bold
            elif context.link and not context.selected:
                fg = 117                # sky
            elif context.executable and not context.selected:
                fg = 151                # green
            elif context.container and not context.selected:
                fg = 211                # pink (archives)

        elif context.in_titlebar:
            attr |= bold
            fg = 183                    # mauve

        elif context.in_statusbar:
            if context.permissions:
                fg = 151 if context.good else 211
            if context.marked:
                attr |= bold
                fg = 223                # yellow

        return fg, bg, attr
