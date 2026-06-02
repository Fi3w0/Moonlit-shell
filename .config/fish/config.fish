if status is-interactive
    # Commands to run in interactive sessions can go here

    # Minecraft server alias
    alias mc "docker exec -it mcserver rcon-cli"
end

fish_add_path $HOME/.spicetify

if status is-interactive
    set -Ux OLLAMA_MODELS $HOME/AI
    alias ai="ollama run qwen2.5-coder:7b"
end

export PATH="$HOME/.local/bin:$PATH"
set -gx PATH $HOME/.local/bin $PATH

# Default editor → neovim
set -gx EDITOR nvim
set -gx VISUAL nvim

# Darker autosuggestion (catppuccin surface1) so it's less washed-out
set -g fish_color_autosuggestion 45475a

# opencode
fish_add_path $HOME/.opencode/bin
