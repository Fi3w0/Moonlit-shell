-- ─── Bootstrap lazy.nvim (plugin manager) ───────────────────────────────
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ─── Plugins ─────────────────────────────────────────────────────────────
require("lazy").setup({
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
      })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
})

-- ─── Custom highlight overrides (your purple/transparent look) ────────────
-- Re-applied on every ColorScheme load so the theme can't clobber them.
local function custom_highlights()
  local set = vim.api.nvim_set_hl
  set(0, "Normal",        { bg = "none", fg = "#E0D7FF" })
  set(0, "NormalNC",      { bg = "none", fg = "#BFAAE0" })
  set(0, "NormalFloat",   { bg = "none" })
  set(0, "FloatBorder",   { fg = "#B388EB", bg = "none" })
  set(0, "LineNr",        { fg = "#7A6FAF", bg = "none" })
  set(0, "CursorLineNr",  { fg = "#CBA6F7", bold = true })
  set(0, "Visual",        { bg = "#2A1E3D" })
  set(0, "Comment",       { fg = "#7A6FAF", italic = true })
  set(0, "String",        { fg = "#E0B0FF" })
  set(0, "Keyword",       { fg = "#CBA6F7", bold = true })
  set(0, "Function",      { fg = "#B388EB" })
  set(0, "Type",          { fg = "#CBA6F7" })
  set(0, "CursorLine",    { bg = "#2A1E3D" })
  set(0, "StatusLine",    { fg = "#B388EB", bg = "none" })
  set(0, "SignColumn",    { bg = "none" })
  set(0, "EndOfBuffer",   { bg = "none", fg = "#1A1423" })
end

vim.api.nvim_create_autocmd("ColorScheme", { callback = custom_highlights })
custom_highlights()
