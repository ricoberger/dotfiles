--------------------------------------------------------------------------------
-- GLOBALS
--------------------------------------------------------------------------------

-- Set the leader to " " (space).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable some built-in plugins, so that they are not loaded.
vim.g.loaded_2html_plugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrw_gitignore = 1
vim.g.loaded_netrwFileHandlers = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_remote_plugins = 1
vim.g.loaded_rplugin = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_tohtml = 1
vim.g.loaded_tutor = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1

-- We are using "Cascadia Code" as font in our terminal, so that we can enable
-- nerd font support in Neovim.
vim.g.have_nerd_font = true

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

vim.opt.background = "dark"
vim.opt.shada = "!,'100,<50,s10,h"
vim.opt.cc = "80,120" -- Display rulers
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard
vim.opt.completeopt = { "menuone", "noselect", "fuzzy", "nosort", "popup" } -- Better completion experience
vim.opt.cursorline = true -- Enable highlighting of the current line
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.exrc = true -- Look for .nvim.lua files in the project directory
vim.opt.formatoptions = "jcroqlnt" -- Automatic formatting behavior
vim.opt.hlsearch = true -- Set highlight on search
vim.opt.ignorecase = true -- Ignore case
vim.opt.inccommand = "split" -- Show live preview of substitution
vim.opt.laststatus = 3 -- global statusline
vim.opt.list = true -- Show some invisible characters
vim.opt.listchars = { tab = "│ ", leadmultispace = "│ " } -- Set characters for invisible characters
vim.opt.mouse = "a" -- Enable mouse mode
vim.opt.number = true -- Print line number
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.scrolloff = 4 -- Lines of context
vim.opt.sessionoptions = { "buffers", "curdir", "folds", "tabpages", "winsize" }
vim.opt.shiftround = true -- Round indent
vim.opt.shiftwidth = 2 -- Size of an indent
vim.opt.shortmess = "I" -- Disable the intro message
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
vim.opt.swapfile = false -- Disable swapfile
vim.opt.tabstop = 2 -- Number of spaces tabs count for
vim.opt.termguicolors = true -- True color support
vim.opt.timeout = false
vim.opt.timeoutlen = 300
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.updatetime = 200 -- Save swap file and trigger CursorHold
vim.opt.wrap = false -- Disable line wrap
vim.opt.wildignore = vim.opt.wildignore + ".DS_Store"

-- Folding
vim.opt.foldcolumn = "0"
vim.opt.foldenable = true
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldmethod = "syntax"
vim.opt.foldtext = ""

-- Better diff experience in Neovim.
vim.opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "context:12",
  "algorithm:histogram",
  "indent-heuristic",
  -- See https://www.reddit.com/r/neovim/comments/1k24zgk/comment/moj5kxj/
  -- "linematch:200",
  "inline:char",
}

-- Enable strikethrough.
vim.cmd([[let &t_Ts = "\e[9m"]])
vim.cmd([[let &t_Te = "\e[29m"]])

-- Enable undercurls.
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

-- Enable the new Neovim UI, which is currently experimental.
require("vim._core.ui2").enable({
  enable = true,
  msg = {
    targets = "cmd",
  },
})

--------------------------------------------------------------------------------
-- FILE HANDLING
--------------------------------------------------------------------------------

-- Handle ".arb" files as ".json" files. ".arb" files are used in Flutter for
-- translations.
vim.filetype.add({
  extension = {
    arb = "json",
  },
})

--------------------------------------------------------------------------------
-- AUTO COMMANDS
--------------------------------------------------------------------------------

-- Highlight on yank.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 250 })
  end,
})

-- Resize splits if window got resized.
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = vim.api.nvim_create_augroup("resize-splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Show cursor line only in active window.
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
  callback = function()
    local ok, cl = pcall(vim.api.nvim_win_get_var, 0, "auto-cursorline")
    if ok and cl then
      vim.wo.cursorline = true
      vim.api.nvim_win_del_var(0, "auto-cursorline")
    end
  end,
})

vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
  callback = function()
    local cl = vim.wo.cursorline
    if cl then
      vim.api.nvim_win_set_var(0, "auto-cursorline", cl)
      vim.wo.cursorline = false
    end
  end,
})

--------------------------------------------------------------------------------
-- KEYMAPS
--------------------------------------------------------------------------------

-- Better up / down navigation for "j" / "down" and "k" / "up".
vim.keymap.set(
  { "n", "x" },
  "j",
  "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true }
)
vim.keymap.set(
  { "n", "x" },
  "<down>",
  "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true }
)
vim.keymap.set(
  { "n", "x" },
  "k",
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true }
)
vim.keymap.set(
  { "n", "x" },
  "<up>",
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true }
)

-- Move to window using the "Ctrl" and arrow keys.
vim.keymap.set("n", "<c-left>", "<c-w>h", { remap = true })
vim.keymap.set("n", "<c-down>", "<c-w>j", { remap = true })
vim.keymap.set("n", "<c-up>", "<c-w>k", { remap = true })
vim.keymap.set("n", "<c-right>", "<c-w>l", { remap = true })

-- Resize windows using "Shift" and arrow keys.
vim.keymap.set("n", "<s-up>", "<cmd>resize +2<cr>")
vim.keymap.set("n", "<s-down>", "<cmd>resize -2<cr>")
vim.keymap.set("n", "<s-left>", "<cmd>vertical resize -2<cr>")
vim.keymap.set("n", "<s-right>", "<cmd>vertical resize +2<cr>")

-- Move lines up and down using "Alt" + "j" / "k" in normal, insert and visual
-- modes.
vim.keymap.set("n", "<m-j>", "<cmd>m .+1<cr>==")
vim.keymap.set("n", "<m-k>", "<cmd>m .-2<cr>==")
vim.keymap.set("i", "<m-j>", "<esc><cmd>m .+1<cr>==gi")
vim.keymap.set("i", "<m-k>", "<esc><cmd>m .-2<cr>==gi")
vim.keymap.set("x", "<m-j>", ":m '>+1<cr>gv=gv")
vim.keymap.set("x", "<m-k>", ":m '<-2<cr>gv=gv")

-- Better indenting in visual mode using "<" and ">".
vim.keymap.set("x", "<", "<gv")
vim.keymap.set("x", ">", ">gv")

-- Clear search with "Esc" in normal and insert mode.
vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>")

-- Copy a reference to the current buffer (filename, directory, path with line /
-- selection or the quickfix list) to the system clipboard, e.g. to paste it
-- into an AI chat.
vim.keymap.set({ "n", "x" }, "<leader>y", function()
  require("core.yank").menu()
end)

--------------------------------------------------------------------------------
-- COMMAND LINE
--------------------------------------------------------------------------------

-- Automatically trigger autocompletion in command line for certain commands,
-- e.g. ":find", ":buffer", ":edit", etc.
vim.api.nvim_create_autocmd({ "CmdlineChanged", "CmdlineLeave" }, {
  pattern = { "*" },
  group = vim.api.nvim_create_augroup(
    "cmdline-autocompletion",
    { clear = true }
  ),
  callback = function(ev)
    local function should_enable_autocomplete()
      local cmdline_cmd = vim.fn.split(vim.fn.getcmdline(), " ")[1]
      return cmdline_cmd == "help"
        or cmdline_cmd == "h"
        or cmdline_cmd == "find"
        or cmdline_cmd == "buffer"
    end

    if ev.event == "CmdlineChanged" and should_enable_autocomplete() then
      vim.opt.wildmode = "noselect:lastused,full"
      vim.fn.wildtrigger()
    end

    if ev.event == "CmdlineLeave" then
      vim.opt.wildmode = "full"
    end
  end,
})

-- Better navigation of the command line wildmenu using the arrow keys. Also
-- Enter: doesn't execute the command, but instead accepts the currently
-- selected item in the wildmenu.
function _G.get_wildmenu_key(key_wildmenu, key_regular)
  return vim.fn.wildmenumode() ~= 0 and key_wildmenu or key_regular
end

vim.api.nvim_set_keymap(
  "c",
  "<down>",
  "v:lua.get_wildmenu_key('<right>', '<down>')",
  { expr = true }
)
vim.api.nvim_set_keymap(
  "c",
  "<up>",
  "v:lua.get_wildmenu_key('<left>', '<up>')",
  { expr = true }
)
vim.api.nvim_set_keymap(
  "c",
  "<cr>",
  "v:lua.get_wildmenu_key('<c-y>', '<cr>')",
  { expr = true }
)

--------------------------------------------------------------------------------
-- COLORSCHEME
--------------------------------------------------------------------------------

-- Set borders for floating windows, popup menus and the command line completion
-- menu. Also set a custom background color for the popup menu and a border
-- color.
vim.opt.winborder = "single"
vim.opt.pumborder = "single"

-- Use the built-in plugin manager to install the Catppuccin theme
--
-- See: https://neovim.io/doc/user/pack.html#_plugin-manager
-- To update all plugins run ":lua vim.pack.update()"
vim.pack.add({
  {
    src = "https://github.com/catppuccin/nvim",
    name = "catppuccin",
    version = "main",
  },
}, { confirm = false, load = true })

-- Setup the Catppuccin theme, by disabling all default integrations and only
-- activating the integrations we are really using.
require("catppuccin").setup({
  flavour = "macchiato",
  default_integrations = false,
  integrations = {
    gitsigns = true,
    native_lsp = {
      enabled = true,
      virtual_text = {
        errors = { "italic" },
        hints = { "italic" },
        warnings = { "italic" },
        information = { "italic" },
        ok = { "italic" },
      },
      underlines = {
        errors = { "undercurl" },
        hints = { "undercurl" },
        warnings = { "undercurl" },
        information = { "undercurl" },
        ok = { "undercurl" },
      },
      inlay_hints = {
        background = true,
      },
    },
    treesitter = true,
  },
  custom_highlights = function(colors)
    local highlights = {
      Pmenu = { bg = colors.mantle },
      PmenuBorder = { bg = colors.mantle, fg = colors.blue },

      -- Picker (see "lua/core/picker.lua").
      PickerNormal = { bg = colors.base },
      PickerBorder = { bg = colors.base, fg = colors.blue },

      -- Explorer marks (see "lua/core/explorer.lua").
      ExplorerMark = { fg = colors.mauve },
      ExplorerMarkLine = { bg = colors.surface0 },

      -- Statusline (see "lua/core/statusline.lua").
      StatuslineC = { fg = colors.text, bg = colors.mantle },
      StatuslineCompSepB = { fg = colors.overlay1, bg = colors.surface0 },
      StatuslineCompSepC = { fg = colors.text, bg = colors.mantle },
      StatuslineSepBC = { fg = colors.surface0, bg = colors.mantle },
      StatuslineSepXY = { fg = colors.surface0, bg = colors.mantle },
      StatuslineDiagError = { fg = colors.red, bg = colors.surface0 },
      StatuslineDiagWarn = { fg = colors.yellow, bg = colors.surface0 },
      StatuslineDiagInfo = { fg = colors.sky, bg = colors.surface0 },
      StatuslineDiagHint = { fg = colors.teal, bg = colors.surface0 },
      StatuslineDiffAdd = { fg = colors.green, bg = colors.surface0 },
      StatuslineDiffChange = { fg = colors.yellow, bg = colors.surface0 },
      StatuslineDiffDelete = { fg = colors.red, bg = colors.surface0 },
    }

    -- Mode-dependent statusline groups, one set per mode color. The key
    -- (e.g. "blue") is used as the highlight group suffix in statusline.lua.
    local mode_colors = {
      blue = colors.blue,
      green = colors.green,
      mauve = colors.mauve,
      red = colors.red,
      peach = colors.peach,
    }
    for key, color in pairs(mode_colors) do
      highlights["StatuslineA_" .. key] =
        { fg = colors.mantle, bg = color, bold = true }
      highlights["StatuslineZ_" .. key] =
        { fg = colors.mantle, bg = color, bold = true }
      highlights["StatuslineB_" .. key] = { fg = color, bg = colors.surface0 }
      highlights["StatuslineSepAB_" .. key] =
        { fg = color, bg = colors.surface0 }
      highlights["StatuslineSepYZ_" .. key] =
        { fg = color, bg = colors.surface0 }
      highlights["StatuslineSepAC_" .. key] = { fg = color, bg = colors.mantle }
    end

    return highlights
  end,
})

vim.cmd.colorscheme("catppuccin-nvim")

--------------------------------------------------------------------------------
-- EXPLORER
--------------------------------------------------------------------------------

-- Open the built-in directory browser (the "dir" plugin) for the directory of
-- the current buffer, or the current working directory when the buffer has no
-- name. Editing a directory path opens a read-only listing that can be
-- navigated with "<CR>" (open entry) and "-" (parent directory). The
-- "core.explorer" module adds file operations to these directory buffers:
-- "<Tab>" marks files, "<C-s>", "<C-v>" and "<C-t>" open the marked files (or
-- the entry under the cursor) in a split, vertical split or new tab, "<C-q>"
-- lists all marks in the quickfix list, "s" greps the directory, "n" creates a
-- new file, "d" deletes, "r" renames, "m" moves and "c" copies the marked files
-- into the current directory and "=" diffs two marked files.
require("core.explorer").setup()

vim.keymap.set("n", "<leader>ee", function()
  local bufname = vim.api.nvim_buf_get_name(0)
  local dir
  if bufname == "" then
    dir = vim.fn.getcwd()
  elseif vim.fn.isdirectory(bufname) == 1 then
    dir = bufname
  else
    dir = vim.fn.fnamemodify(bufname, ":p:h")
  end
  vim.cmd.edit(vim.fn.fnameescape(dir))
end)

-- Keymap to save a file without running any auto commands and with creating
-- directories.
vim.keymap.set("n", "<leader>ew", "<cmd>noautocmd write ++p<cr>")

--------------------------------------------------------------------------------
-- FIND FILES
--------------------------------------------------------------------------------

local find_command =
  "fd --full-path --hidden --color never --type f --exclude .git --exclude node_modules --exclude dist --exclude .DS_Store"
local find_cache = {}

-- Use "fd" to find files with the "find" command. Together with the
-- "matchfuzzy()" function this should replace any external fuzzy finder plugin.
-- The files are cached until the command line is closed. Afterwards the cache
-- is cleared.
function _G.fd_find_files(arg, _)
  if #find_cache == 0 then
    find_cache = vim.fn.systemlist(find_command)
  end
  return #arg == 0 and find_cache or vim.fn.matchfuzzy(find_cache, arg)
end

vim.opt.findfunc = "v:lua.fd_find_files"

vim.api.nvim_create_autocmd({ "CmdlineLeave" }, {
  pattern = ":",
  group = vim.api.nvim_create_augroup(
    "find-command-clear-cache",
    { clear = true }
  ),
  callback = function(ev)
    if ev.event == "CmdlineLeave" then
      find_cache = {}
    end
  end,
})

-- Keymaps for finding files, buffers and recent files (filtered to the current
-- working directory) using our fzf based picker.
vim.keymap.set("n", "<leader>ff", function()
  require("core.picker").find_files()
end)
vim.keymap.set("n", "<leader>fb", function()
  require("core.picker").buffers()
end)
vim.keymap.set("n", "<leader>fr", function()
  require("core.picker").recent()
end)

--------------------------------------------------------------------------------
-- SEARCH THROUGH FILES
--------------------------------------------------------------------------------

-- Use "rg" (ripgrep) to search though files with the "grep" command.
vim.opt.grepprg =
  "rg --vimgrep --smart-case --hidden --color=never --glob='!.git' --glob='!node_modules' --glob='!dist' --glob='!.DS_Store'"
vim.opt.grepformat = "%f:%l:%c:%m"

-- Keymaps for searching through files using our fzf based picker. "<leader>sw"
-- greps the word under the cursor (or the visual selection) and "<leader>st"
-- greps for common todo / warning tags.
vim.keymap.set("n", "<leader>ss", function()
  require("core.picker").grep_project()
end)
vim.keymap.set({ "n", "x" }, "<leader>sw", function()
  require("core.picker").grep_word()
end)
vim.keymap.set("n", "<leader>st", function()
  require("core.picker").grep_todos()
end)

--------------------------------------------------------------------------------
-- REPLACE
--------------------------------------------------------------------------------

-- Replace in the current buffer or in all items in the quickfix list. Replace
-- in the current buffer also works for a visual selection.
vim.keymap.set(
  { "n" },
  "<leader>rr",
  [[:%s///gcI<left><left><left><left><left>]]
)
vim.keymap.set("x", "<leader>rr", [[:s///gcI<left><left><left><left><left>]])
vim.keymap.set(
  "n",
  "<leader>rw",
  [[:%s/\<<c-r><c-w>\>//gcI<left><left><left><left>]]
)
vim.keymap.set(
  "x",
  "<leader>rw",
  [[y:%s/\V<c-r>"//gcI<left><left><left><left>]]
)
vim.keymap.set(
  "n",
  "<leader>rR",
  [[:cfdo %s///gcI | update]]
    .. [[<left><left><left><left><left><left><left><left><left><left><left><left><left><left>]]
)
vim.keymap.set(
  "n",
  "<leader>rW",
  [[:cfdo %s/\<<c-r><c-w>\>//gcI | update]]
    .. [[<left><left><left><left><left><left><left><left><left><left><left><left><left>]]
)
vim.keymap.set(
  "x",
  "<leader>rW",
  [[y:cfdo %s/\V<c-r>"//gcI | update]]
    .. [[<left><left><left><left><left><left><left><left><left><left><left><left><left>]]
)

--------------------------------------------------------------------------------
-- QUICKFIX LIST
--------------------------------------------------------------------------------

-- Remove items from the quickfix list via "dd" in normal mode and "d" in
-- visual mode.
--
-- See: https://github.com/rmarganti/.dotfiles/blob/e08a5d8f1462b573e0cf9a01fb54403111b9aceb/dots/.config/nvim/lua/rmarganti/core/autocommands.lua#L12
local function delete_qf_items()
  local mode = vim.api.nvim_get_mode()["mode"]

  local start_idx
  local count

  if mode == "n" then
    start_idx = vim.fn.line(".")
    count = vim.v.count > 0 and vim.v.count or 1
  else
    local v_start_idx = vim.fn.line("v")
    local v_end_idx = vim.fn.line(".")

    start_idx = math.min(v_start_idx, v_end_idx)
    count = math.abs(v_end_idx - v_start_idx) + 1

    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<esc>", true, false, true),
      "x",
      false
    )
  end

  local qflist = vim.fn.getqflist()
  local title = vim.fn.getqflist({ title = 1 })

  for _ = 1, count, 1 do
    table.remove(qflist, start_idx)
  end

  vim.fn.setqflist({}, "r", { title = title.title, items = qflist })
  vim.fn.cursor(start_idx, 1)
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup(
    "delete-quickfix-items",
    { clear = true }
  ),
  pattern = "qf",
  callback = function()
    vim.keymap.set("n", "dd", delete_qf_items, { buffer = true })
    vim.keymap.set("x", "d", delete_qf_items, { buffer = true })
  end,
})

-- Automatically open the quickfix window if there are any entries in the
-- quickfix list, e.g. after running ":grep".
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  group = vim.api.nvim_create_augroup("auto-open-quickfix", { clear = true }),
  pattern = { "[^l]*" },
  command = "cwindow",
})

--------------------------------------------------------------------------------
-- TREESITTER
--------------------------------------------------------------------------------

-- Install the nvim-treesitter plugin and ensure that some parsers are always
-- installed. We also allow auto installing of additional parsers.
vim.pack.add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    name = "nvim-treesitter",
    version = "main",
  },
}, { confirm = false, load = true })

require("nvim-treesitter").setup({
  install_dir = vim.fn.stdpath("data") .. "/site",
})

local ts_parsers = {
  "bash",
  "css",
  "dart",
  "diff",
  "dockerfile",
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",
  "go",
  "gomod",
  "gosum",
  "helm",
  "html",
  "javascript",
  "json",
  "lua",
  "make",
  "markdown",
  "markdown_inline",
  "python",
  "regex",
  "rust",
  "sql",
  "terraform",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "yaml",
  "zig",
}

local ts = require("nvim-treesitter")
vim.schedule(function()
  ts.install(ts_parsers)
end)

-- Update treesitter parsers / queries with plugin updates.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup(
    "nvim-treesitter-pack-update-handler",
    { clear = true }
  ),
  callback = function(event)
    local spec = event.data.spec
    if
      spec
      and spec.name == "nvim-treesitter"
      and event.data.kind == "update"
    then
      vim.schedule(function()
        ts.update()
      end)
    end
  end,
})

-- Enable treesitter highlighting and indents.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup(
    "nvim-treesitter-enable-highlighting-and-indents-handler",
    { clear = true }
  ),
  callback = function(event)
    local filetype = event.match
    local lang = vim.treesitter.language.get_lang(filetype)
    if vim.treesitter.language.add(lang) then
      if vim.treesitter.query.get(filetype, "indents") then
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
      if vim.treesitter.query.get(filetype, "folds") then
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"
      end
      vim.treesitter.start()
    end
  end,
})

--------------------------------------------------------------------------------
-- LSP
--------------------------------------------------------------------------------

-- Handle "docker-compose.yaml" and "docker-compose.yml" files as
-- "yaml.docker-compose" files, so that they get the correct filetype and the
-- "docker_compose_language_service" LSP server can be used for them.
vim.filetype.add({
  pattern = {
    ["compose.*%.ya?ml"] = "yaml.docker-compose",
    ["docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
  },
})

-- Install the "helm-ls" plugin, which is required for the Helm Language Server
-- (helm_ls) to work properly.
--
-- See: https://github.com/mrjosh/helm-ls/blob/master/README.md#neovim
vim.pack.add({
  {
    src = "https://github.com/qvalentin/helm-ls.nvim",
    name = "helm-ls",
    version = "main",
  },
}, { confirm = false, load = true })

require("helm-ls").setup({
  conceal_templates = {
    enabled = false,
  },
  indent_hints = {
    enabled = false,
    only_for_current_line = false,
  },
})

-- Enable and configure the built-in LSP client.
vim.lsp.enable({
  "bashls",
  "copilot",
  "dartls",
  "denols",
  "dockerls",
  "docker_compose_language_service",
  "efm",
  "eslint",
  "filepaths_ls",
  "golangci_lint_ls",
  "gopls",
  "helm_ls",
  "lua_ls",
  "marksman",
  "my_hover_ls",
  "prlsp",
  "pyright",
  "rust_analyzer",
  "sourcekit",
  "terraformls",
  "tsgo",
  "yamlls",
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    local buffer = event.buf

    if client then
      -- Add additional keymaps to the default LSP keymaps.
      -- See: https://neovim.io/doc/user/lsp.html#_global-defaults
      vim.keymap.set("n", "grf", function()
        vim.lsp.buf.format({
          timeout_ms = 60000,
        })
      end)
      vim.keymap.set("n", "gd", function()
        vim.lsp.buf.definition({ loclist = false })
      end)
      vim.keymap.set("n", "gD", function()
        vim.lsp.buf.declaration({ loclist = false })
      end)
      vim.keymap.set("n", "grh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end)

      -- -- Add "<leader>mlo" keymap for tsgo to organize imports, since the
      -- -- default code action keymap "gra" does not provide it.
      -- vim.keymap.set("n", "<leader>mlo", function()
      --   vim.lsp.buf.code_action({
      --     context = { only = { "source.organizeImports" }, diagnostics = {} },
      --     apply = true,
      --   })
      -- end)

      -- Enable completion.
      if
        client:supports_method(vim.lsp.protocol.Methods.textDocument_completion)
      then
        vim.lsp.completion.enable(
          true,
          client.id,
          buffer,
          { autotrigger = true }
        )
        vim.keymap.set("i", "<c-space>", function()
          vim.lsp.completion.get()
        end)
      end

      -- Enable LLM-based inline completions.
      if
        client:supports_method(
          vim.lsp.protocol.Methods.textDocument_inlineCompletion
        )
      then
        vim.lsp.inline_completion.enable(true)

        -- Accept the currently shown inline completion with "Ctrl+Enter". If no
        -- inline completion is currently shown, insert a newline as usual.
        vim.keymap.set("i", "<c-cr>", function()
          if not vim.lsp.inline_completion.get() then
            return "<c-cr>"
          end
        end, { expr = true, replace_keycodes = true })

        -- Accept the currently shown inline completion word by word with
        -- "Ctrl+Right". If no inline completion is currently shown, move the
        -- cursor to the right as usual.
        vim.keymap.set("i", "<c-right>", function()
          if
            not vim.lsp.inline_completion.get({
              on_accept = function(item)
                local insert_text = item.insert_text
                if type(insert_text) ~= "string" or not item.range then
                  return nil
                end
                local end_ = item.range[4]

                local before_text = string.sub(insert_text, 1, end_)
                local after_text = string.sub(insert_text, end_ + 1)
                local next_word = string.match(after_text, "(%s?[^%s]+)")

                item.insert_text = before_text .. next_word
                return item
              end,
            })
          then
            return "<c-right>"
          end
        end, { expr = true, replace_keycodes = true })
      end

      -- Add normal-mode keymappings for signature help.
      if client:supports_method("textDocument/signatureHelp") then
        vim.keymap.set("n", "<c-s>", function()
          vim.lsp.buf.signature_help()
        end)
      end

      -- Enable folding based on LSP.
      if client:supports_method("textDocument/foldingRange") then
        local win = vim.api.nvim_get_current_win()
        vim.wo[win][0].foldmethod = "expr"
        vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
      end

      -- Auto-format on save.
      if client:supports_method("textDocument/formatting") then
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = buffer,
          callback = function()
            vim.lsp.buf.format({ bufnr = buffer, id = client.id })
          end,
        })
      end
    end

    -- If the prlsp client is attached, load the prlsp plugin and add keymaps
    -- for creating, replying to and showing review comments.
    if client and client.name == "prlsp" then
      require("core.prlsp")

      vim.keymap.set(
        { "n", "x" },
        "<leader>ghc",
        ":PRLSPCreateReviewComment<cr>",
        { silent = true }
      )
      vim.keymap.set("n", "<leader>ghr", "<cmd>PRLSPReplyToReviewThread<cr>")
      vim.keymap.set("n", "<leader>ghs", "<cmd>PRLSPShowReviewThread<cr>")
      vim.keymap.set("n", "<leader>ghu", "<cmd>PRLSPRefreshReviewThreads<cr>")
    end
  end,
})

-- Show LSP progress messages. It will also show a progress bar via Ghostty. In
-- case Neovim is exiting while the LSP is still running, it will send an OSC
-- sequence to Ghostty to make sure the progress bar is removed.
vim.api.nvim_create_autocmd("LspProgress", {
  callback = function(event)
    local value = event.data.params.value or {}
    local msg = value.message or "done"

    vim.api.nvim_echo({ { msg } }, false, {
      id = "lsp",
      kind = "progress",
      source = "vim.lsp",
      title = value.title,
      status = value.kind ~= "end" and "running" or "success",
      percent = value.percentage,
    })
  end,
})

vim.api.nvim_create_autocmd({ "VimLeavePre", "ExitPre" }, {
  callback = function()
    if vim.env.TERM and vim.env.TERM:match("ghostty") then
      local osc = "\27]9;4;0;100\a"
      vim.api.nvim_chan_send(vim.v.stderr, osc)
    end
  end,
})

--------------------------------------------------------------------------------
-- DIAGNOSTICS
--------------------------------------------------------------------------------

local icons_diagnostics = {
  Error = " ",
  Warn = " ",
  Info = " ",
  Hint = " ",
}

vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    prefix = function(diagnostic)
      for d, icon in pairs(icons_diagnostics) do
        if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
          return icon
        end
      end
    end,
    format = function(diagnostic)
      -- Replace newline and tab characters with space for more compact
      -- diagnostics.
      local message = diagnostic.message
        :gsub("\n", " ")
        :gsub("\t", " ")
        :gsub("%s+", " ")
        :gsub("^%s+", "")
      return message
    end,
  },
  -- virtual_lines = true,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.HINT] = icons_diagnostics.Hint,
      [vim.diagnostic.severity.INFO] = icons_diagnostics.Info,
      [vim.diagnostic.severity.WARN] = icons_diagnostics.Warn,
      [vim.diagnostic.severity.ERROR] = icons_diagnostics.Error,
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
  vim.fn.sign_define("DiagnosticSign" .. type, {
    name = "DiagnosticSign" .. type,
    text = icons_diagnostics[type],
    texthl = "Diagnostic" .. type,
  })
end

vim.keymap.set("n", "<leader>d", function()
  vim.diagnostic.setqflist()
end, {})

--------------------------------------------------------------------------------
-- STATUSLINE
--------------------------------------------------------------------------------

require("core.statusline")

--------------------------------------------------------------------------------
-- GIT
--------------------------------------------------------------------------------

local icons_git = {
  -- Change type
  added = "✚",
  modified = "○",
  deleted = "✖",
  untracked = "",
}

-- Install gitsigns and use our icons instead of the default ones.
vim.pack.add({
  {
    src = "https://github.com/lewis6991/gitsigns.nvim",
    name = "gitsigns",
    version = "main",
  },
}, { confirm = false, load = true })

require("gitsigns").setup({
  signs = {
    add = { text = icons_git.added },
    change = { text = icons_git.modified },
    delete = { text = icons_git.deleted },
    topdelete = { text = icons_git.deleted },
    changedelete = { text = icons_git.modified },
    untracked = { text = icons_git.untracked },
  },
  signs_staged = {
    add = { text = icons_git.added },
    change = { text = icons_git.deleted },
    delete = { text = icons_git.deleted },
    topdelete = { text = icons_git.deleted },
    changedelete = { text = icons_git.modified },
    untracked = { text = icons_git.untracked },
  },
  preview_config = {
    border = "single",
  },
  on_attach = function(bufnr)
    -- Define keymaps for Git related actions provided by gitsigns.
    local gitsigns = require("gitsigns")

    -- Go to next / previous hunk.
    vim.keymap.set("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gitsigns.nav_hunk("next")
      end
    end, { buffer = bufnr })
    vim.keymap.set("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gitsigns.nav_hunk("prev")
      end
    end, { buffer = bufnr })

    -- Stage / reset / preview hunk(s).
    vim.keymap.set("n", "<leader>gss", gitsigns.stage_hunk, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsr", gitsigns.reset_hunk, { buffer = bufnr })
    vim.keymap.set("v", "<leader>gss", function()
      gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, { buffer = bufnr })
    vim.keymap.set("v", "<leader>gsr", function()
      gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, { buffer = bufnr })
    vim.keymap.set(
      "n",
      "<leader>gsS",
      gitsigns.stage_buffer,
      { buffer = bufnr }
    )
    vim.keymap.set(
      "n",
      "<leader>gsR",
      gitsigns.reset_buffer,
      { buffer = bufnr }
    )
    vim.keymap.set(
      "n",
      "<leader>gsu",
      gitsigns.undo_stage_hunk,
      { buffer = bufnr }
    )
    vim.keymap.set(
      "n",
      "<leader>gsp",
      gitsigns.preview_hunk,
      { buffer = bufnr }
    )

    -- Blame line and show full commit details.
    vim.keymap.set("n", "<leader>gsb", function()
      gitsigns.blame_line({ full = true })
    end, { buffer = bufnr })

    -- Git diff.
    vim.keymap.set("n", "<leader>gsd", gitsigns.diffthis, { buffer = bufnr })

    -- Show hunks in quickfix list.
    vim.keymap.set("n", "<leader>gsq", function()
      gitsigns.setqflist("all")
    end, { buffer = bufnr })

    -- Toggle word diff and deleted lines.
    vim.keymap.set("n", "<leader>gst", function()
      gitsigns.toggle_linehl()
      gitsigns.toggle_word_diff()
      gitsigns.toggle_deleted()
    end, { buffer = bufnr })
  end,
})

-- The "GitDiff <base> <head>" command shows the diff of two branches via
-- gitsigns. If no branches are provided the diff between the current branch
-- and the default branch is shown. It also populates the quickfix list with the
-- hunks.
vim.api.nvim_create_user_command("GitDiff", function(opts)
  local base = ""
  local head = ""

  if #vim.fn.split(opts.args, " ") == 2 then
    base = vim.fn.split(opts.args, " ")[1]
    head = vim.fn.split(opts.args, " ")[2]
  else
    base = vim.fn.system("git branch --show-current"):gsub("[\r\n]", "")
    head = vim.fn
      .system("git remote show origin | sed -n '/HEAD branch/s/.*: //p'")
      :gsub("[\r\n]", "")
  end

  local result = vim.system({ "git", "merge-base", base, head }):wait()
  if result.code ~= 0 then
    return
  end

  local commit = vim.fn.trim(result.stdout)

  local gitsigns = require("gitsigns")
  gitsigns.change_base(commit, true)
  gitsigns.setqflist("all")
end, { nargs = "*" })

vim.keymap.set("n", "<leader>gsD", "<cmd>GitDiff<cr>")

-- Find all merge conflicts in the current Git repository and display them in
-- the quickfix list.
--
-- See: https://github.com/git/git/blob/215033b3ac599432a17d58f18a92b356d98354a9/contrib/git-jump/git-jump#L59
vim.keymap.set("n", "<leader>gfm", function()
  local items = {}
  local files = vim.fn.systemlist(
    "git ls-files -u | perl -pe 's/^.*?\t//' | sort -u | while IFS= read fn; do grep -Hn '^<<<<<<<' \"$fn\"; done"
  )

  for _, file in ipairs(files) do
    local parts = vim.fn.split(file, ":")
    table.insert(items, {
      filename = parts[1],
      lnum = tonumber(parts[2]),
    })
  end

  vim.fn.setqflist({}, " ", { title = "Merge Conflicts", items = items })
  vim.cmd.copen()
end)

-- Keymaps for the Git pickers ("gf" = git find). "enter" opens the file /
-- checks out the branch, "ctrl-q" sends the selection to the quickfix list and
-- "ctrl-s" / "ctrl-v" / "ctrl-t" open in a horizontal / vertical split or a new
-- tab (file pickers only).
vim.keymap.set("n", "<leader>gff", function()
  require("core.picker").git_files()
end)
vim.keymap.set("n", "<leader>gfb", function()
  require("core.picker").git_branches()
end)
vim.keymap.set("n", "<leader>gfd", function()
  require("core.picker").git_diff()
end)
vim.keymap.set("n", "<leader>gfs", function()
  require("core.picker").git_status()
end)
vim.keymap.set("n", "<leader>gfz", function()
  require("core.picker").git_stash()
end)
vim.keymap.set("n", "<leader>gfl", function()
  require("core.picker").git_file_log()
end)
vim.keymap.set("n", "<leader>gfL", function()
  require("core.picker").git_log()
end)

--------------------------------------------------------------------------------
-- MULTICURSOR
--------------------------------------------------------------------------------

vim.pack.add({
  {
    src = "https://github.com/jake-stewart/multicursor.nvim",
    name = "multicursor",
    version = "main",
  },
}, { confirm = false, load = true })

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup(
    "lazy-load-multicursor",
    { clear = true }
  ),
  once = true,
  callback = function()
    local mc = require("multicursor-nvim")
    mc.setup()

    -- Define keymaps for multicursor operations. A new cursor can be added
    -- using "Ctrl + k" / "Ctrl + j" for the line above / below, using
    -- "Ctrl + n" for the next word under the cursor "Ctrl + a" for all
    -- occurrences of the word under the cursor or using "Ctrl = m" for all
    -- provided matches.
    vim.keymap.set("n", "<c-k>", function()
      mc.addCursor("k")
    end)
    vim.keymap.set("n", "<c-j>", function()
      mc.addCursor("j")
    end)
    vim.keymap.set({ "n", "x" }, "<c-n>", function()
      mc.addCursor("*")
    end)
    vim.keymap.set({ "n", "x" }, "<c-a>", mc.matchAllAddCursors)
    vim.keymap.set("x", "<c-m>", mc.matchCursors)

    mc.addKeymapLayer(function(layerSet)
      layerSet("n", "<esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        else
          mc.clearCursors()
        end
      end)
    end)

    -- Customize highlight groups for multicursor.
    local hl = vim.api.nvim_set_hl
    hl(0, "MultiCursorCursor", { link = "Cursor" })
    hl(0, "MultiCursorVisual", { link = "Visual" })
    hl(0, "MultiCursorSign", { link = "SignColumn" })
    hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
    hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
    hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
  end,
})

--------------------------------------------------------------------------------
-- NOTES
--------------------------------------------------------------------------------

local notes_dir = "/Users/ricoberger/Documents/GitHub/ricoberger/notes"

-- Open today's daily note (creating it from the template) or yesterday's note.
vim.keymap.set("n", "<leader>nd", function()
  local date = vim.fn.strftime("%Y/%m/%Y-%m-%d")
  local path = notes_dir .. "/daily/" .. date .. ".md"
  if vim.uv.fs_stat(path) then
    vim.cmd("e " .. path)
  else
    vim.cmd("e " .. path)
    vim.cmd("r " .. notes_dir .. "/daily/template.md")
  end
end)

vim.keymap.set("n", "<leader>ny", function()
  local date = vim.fn.strftime("%Y/%m/%Y-%m-%d", vim.fn.localtime() - 3600 * 24)
  vim.cmd("e " .. notes_dir .. "/daily/" .. date .. ".md")
end)

-- Open the explorer for the notes directory. When the current buffer is inside
-- the notes directory the folder containing the buffer is shown, otherwise the
-- root of the notes directory is shown.
vim.keymap.set("n", "<leader>ne", function()
  local bufname = vim.api.nvim_buf_get_name(0)
  local dir = notes_dir
  if bufname ~= "" then
    local path = vim.fn.fnamemodify(bufname, ":p")
    if vim.startswith(path, notes_dir .. "/") then
      if vim.fn.isdirectory(path) == 1 then
        dir = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
      else
        dir = vim.fn.fnamemodify(bufname, ":p:h")
      end
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(dir))
end)

-- Notes pickers, scoped to the notes directory. "<leader>nt" lists all open
-- todos ("- [ ]") and "<leader>nk" lists all note tags.
vim.keymap.set("n", "<leader>nf", function()
  require("core.picker").find_files({
    cwd = notes_dir,
    icon = "",
    title = "Notes",
  })
end)
vim.keymap.set("n", "<leader>nr", function()
  require("core.picker").recent({ cwd = notes_dir, icon = "", title = "Notes" })
end)
vim.keymap.set("n", "<leader>ns", function()
  require("core.picker").grep_project({
    cwd = notes_dir,
    icon = "",
    title = "Notes",
  })
end)
vim.keymap.set("n", "<leader>nt", function()
  require("core.picker").grep_pattern(
    [[- \[ \] .*]],
    { cwd = notes_dir, icon = "", title = "Notes Todos" }
  )
end)
vim.keymap.set("n", "<leader>nk", function()
  require("core.picker").grep_pattern(
    [[^tags: \[.*\]$]],
    { cwd = notes_dir, icon = "", title = "Notes Tags" }
  )
end)
