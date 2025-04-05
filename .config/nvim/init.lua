vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("core.options")
require("core.keymaps")
require("core.autocmds")

require("lazy").setup({
  { import = "core.plugins.colorscheme" },
  { import = "core.plugins.qol" },
  { import = "core.plugins.statusline" },
  { import = "core.plugins.git" },
  { import = "core.plugins.completion" },
  { import = "core.plugins.multicursor" },
  { import = "core.plugins.comments" },
  { import = "core.plugins.formatting" },
  { import = "core.plugins.linting" },
  { import = "core.plugins.treesitter" },
  { import = "core.plugins.ai" },
})

require("core.lsp")
