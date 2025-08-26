vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1

vim.cmd([[
  set noswapfile
  set shortmess=I
]])

-- Undercurl
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

vim.opt.background = "dark"
vim.opt.cc = "80,120" -- Display rulers
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard
vim.opt.completeopt = "menu,menuone,noselect" -- Better completion experience
vim.opt.cursorline = true -- Enable highlighting of the current line
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.exrc = true -- Look for .nvim.lua files in the project directory
vim.opt.foldcolumn = "0"
vim.opt.foldenable = true
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldmethod = "expr"
vim.opt.foldtext = ""
vim.opt.formatoptions = "jcroqlnt" -- tcqj
vim.opt.hlsearch = true -- Set highlight on search
vim.opt.ignorecase = true -- Ignore case
vim.opt.inccommand = "split" -- Show live preview of substitution
vim.opt.laststatus = 3 -- global statusline
-- vim.opt.list = true -- Show some invisible characters
-- vim.opt.listchars = { space = '·', tab = '▸ ', trail = '·', eol = '↵', nbsp = '_' } -- Set characters for invisible characters
vim.opt.mouse = "a" -- Enable mouse mode
vim.opt.number = true -- Print line number
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.scrolloff = 4 -- Lines of context
vim.opt.shiftround = true -- Round indent
vim.opt.shiftwidth = 2 -- Size of an indent
vim.opt.showtabline = 0 -- Disable tabline
vim.opt.sidescrolloff = 8 -- Columns of context
vim.opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
vim.opt.smartcase = true -- Don't ignore case with capitals
vim.opt.smartindent = true -- Insert indents automatically
vim.opt.spell = false
vim.opt.spelllang = { "en_us" }
vim.opt.splitbelow = true -- Put new windows below current
vim.opt.splitkeep = "screen"
vim.opt.splitright = true -- Put new windows right of current
vim.opt.tabstop = 2 -- Number of spaces tabs count for
vim.opt.termguicolors = true -- True color support
vim.opt.timeout = false
vim.opt.timeoutlen = 300
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.updatetime = 200 -- Save swap file and trigger CursorHold
vim.opt.wrap = false -- Disable line wrap
vim.opt.winborder = "none"

vim.opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "context:12",
  "algorithm:histogram",
  "linematch:200",
  "indent-heuristic",
}

-- Set diagnostic icons
local icons = require("utils").icons

vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    -- prefix = "●",
    prefix = function(diagnostic)
      for d, icon in pairs(icons.diagnostics) do
        if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
          return icon
        end
      end
    end,
    format = function(diagnostic)
      -- Replace newline and tab characters with space for more compact diagnostics
      local message = diagnostic.message:gsub("\n", " "):gsub("\t", " "):gsub("%s+", " "):gsub("^%s+", "")
      return message
    end,
  },
  -- virtual_lines = true,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.HINT] = icons.diagnostics.Hint,
      [vim.diagnostic.severity.INFO] = icons.diagnostics.Info,
      [vim.diagnostic.severity.WARN] = icons.diagnostics.Warn,
      [vim.diagnostic.severity.ERROR] = icons.diagnostics.Error,
    },
    linehl = {
      [vim.diagnostic.severity.HINT] = "DiagnosticHint",
      [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
      [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
      [vim.diagnostic.severity.ERROR] = "DiagnosticError",
    },
  },
})

for _, type in ipairs({ "Error", "Warn", "Hint", "Info" }) do
  vim.fn.sign_define(
    "DiagnosticSign" .. type,
    { name = "DiagnosticSign" .. type, text = icons.diagnostics[type], texthl = "Diagnostic" .. type }
  )
end

-- Handle ".arb" files as ".json" files
vim.filetype.add({
  extension = {
    arb = "json",
  },
})
