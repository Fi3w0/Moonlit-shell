from ranger.gui.colorscheme import ColorScheme
from ranger.gui.color import bold, normal, default_colors

class Scheme(ColorScheme):
    def use(self, context):
        fg, bg, attr = 254, -1, normal

        if context.reset:
            return default_colors

        elif context.in_browser:
            # --- DARK PURPLE SELECTION ---
            if context.selected:
                bg = 54             # Saturated Dark Purple background
                fg = 255            # Bright White text
                attr = bold
            
            if context.directory:
                if not context.selected: fg = 141
                attr |= bold
            elif context.executable and not context.selected:
                fg = 149 
            elif context.container and not context.selected:
                fg = 203

        elif context.in_titlebar:
            fg = 183 
            attr |= bold

        return fg, -1, attr
