-- share/nvim/runtime/ftplugin/markdown.lua overrides our original definition of
-- "gO". So we have to redifne it here to call our own function instead of the
-- default one.
vim.keymap.set("n", "gO", function()
  Snacks.picker.lsp_symbols()
end, { buffer = 0, silent = true })
