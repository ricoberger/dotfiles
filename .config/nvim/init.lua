--------------------------------------------------------------------------------
-- GLOBALS
--------------------------------------------------------------------------------

-- Set the leader to " " (space).
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Disable some built-in plugins, so that they are not loaded.
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
vim.g.loaded_netrw_gitignore = 1

-- We are using "Cascadia Code" as font in our terminal, so that we can enable
-- nerd font support in Neovim.
vim.g.have_nerd_font = true

-- Define icons for diagnostics and git.
local icons = {
  diagnostics = {
    Error = " ",
    Warn = " ",
    Hint = " ",
    Info = " ",
  },
  git = {
    -- Change type
    added = "✚",
    modified = "○",
    deleted = "✖",
    renamed = "󰁕",
    -- Status type
    untracked = "",
    ignored = "",
    unstaged = "󰄱",
    staged = "󰱒",
    conflict = "",
    -- Snacks
    commit = "󰜘",
    unmerged = " ",
  },
}

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

vim.opt.background = "dark"
vim.opt.cc = "80,120" -- Display rulers
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard
vim.opt.completeopt = { "menuone", "noselect", "fuzzy", "nosort", "popup" } -- Better completion experience
vim.opt.cursorline = true -- Enable highlighting of the current line
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.exrc = true -- Look for .nvim.lua files in the project directory
vim.opt.formatoptions = "jcroqlnt" -- tcqj
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
vim.opt.winborder = "none"

-- Folding
vim.opt.foldcolumn = "0"
vim.opt.foldenable = true
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldmethod = "expr"
vim.opt.foldtext = ""

-- Better diff experience in Neovim.
vim.opt.diffopt = {
  "internal",
  "filler",
  "closeoff",
  "context:12",
  "algorithm:histogram",
  "linematch:200",
  "indent-heuristic",
}

-- Enable undercurls.
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

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
vim.keymap.set("v", "<m-j>", ":m '>+1<cr>gv=gv")
vim.keymap.set("v", "<m-k>", ":m '<-2<cr>gv=gv")

-- Better indenting in visual mode using "<" and ">".
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- Clear search with "Esc" in normal and insert mode.
vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>")

-- Surround the visual selection with parentheses, brackets, braces or quotes.
vim.keymap.set("v", "gs(", "<esc>`>a)<esc>`<i(<esc>")
vim.keymap.set("v", "gs)", "<esc>`>a)<esc>`<i(<esc>")
vim.keymap.set("v", "gs{", "<esc>`>a}<esc>`<i{<esc>")
vim.keymap.set("v", "gs}", "<esc>`>a}<esc>`<i{<esc>")
vim.keymap.set("v", "gs[", "<esc>`>a]<esc>`<i[<esc>")
vim.keymap.set("v", "gs]", "<esc>`>a]<esc>`<i[<esc>")
vim.keymap.set("v", "gs<", "<esc>`>a><esc>`<i<<esc>")
vim.keymap.set("v", "gs>", "<esc>`>a><esc>`<i<<esc>")
vim.keymap.set("v", 'gs"', '<esc>`>a"<esc>`<i"<esc>')
vim.keymap.set("v", "gs'", "<esc>`>a'<esc>`<i'<esc>")
vim.keymap.set("v", "gs`", "<esc>`>a`<esc>`<i`<esc>")

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
        or cmdline_cmd == "Find"
        or cmdline_cmd == "buffer"
        or cmdline_cmd == "edit"
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
-- "Enter: doesn't execute the command, but instead accepts the currently
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

-- Change the command in the command line. This can be used together with the
-- fuzzy finder and file explorer keymaps above.
vim.keymap.set("c", "<m-e>", "<home><s-right><c-w>edit<end>")
vim.keymap.set("c", "<m-v>", "<home><s-right><c-w>vsplit<end>")
vim.keymap.set("c", "<m-s>", "<home><s-right><c-w>split<end>")
vim.keymap.set("c", "<m-t>", "<home><s-right><c-w>tabedit<end>")
vim.keymap.set("c", "<m-r>", "<home><s-right><c-w>!rm<end>")

--------------------------------------------------------------------------------
-- EXPLORER
--------------------------------------------------------------------------------

-- Add keymaps for some "file explorer" operations, like opening the "explorer"
-- in the directory of the current file, copy, move, delete and yank the path of
-- the current file.
vim.keymap.set("n", "<leader>ee", function()
  local dir = vim.fn.expand("%:.:h")
  if dir == "." or dir == "" then
    return ":edit "
  end
  return ":edit " .. vim.fn.expand("%:.:h") .. "/"
end, { expr = true })
vim.keymap.set("n", "<leader>ec", function()
  return ":!cp " .. vim.fn.expand("%:.") .. " " .. vim.fn.expand("%:.")
end, { expr = true })
vim.keymap.set("n", "<leader>em", function()
  return ":!mv " .. vim.fn.expand("%:.") .. " " .. vim.fn.expand("%:.")
end, { expr = true })
vim.keymap.set("n", "<leader>er", function()
  return ":!rm " .. vim.fn.expand("%:.")
end, { expr = true })
vim.keymap.set("n", "<leader>ey", function()
  vim.fn.setreg("+", vim.fn.expand("%:."))
end)
vim.keymap.set("n", "<leader>ew", "<cmd>write<cr>")
vim.keymap.set("n", "<leader>eW", "<cmd>noautocmd write<cr>")

--------------------------------------------------------------------------------
-- FIND FILES
--------------------------------------------------------------------------------

local findCommand =
  "fd --full-path --hidden --color never --type f --exclude .git"

-- If "fd" is installed we use it to find files with the "find" command.
-- Together with the "matchfuzzy()" function this should replace any external
-- fuzzy finder plugin.
--
-- Maybe we can also use "fzf" in the future if the results returned by the
-- "matchfuzzy()" function are not satisfying, e.g.
-- "return vim.fn.systemlist( "fd --full-path --hidden --color never --type f --exclude .git | fzf --filter='" .. cmdarg .. "'")"
--
-- If we do not want to use "fd" we can also use "rg", which we will also use
-- for searching through files: "rg --files --hidden --color=never --glob='!.git'"
if vim.fn.executable("fd") == 1 then
  function _G.fd_find_files(cmdarg, _)
    local fnames = vim.fn.systemlist(findCommand)

    if #cmdarg == 0 then
      return fnames
    else
      return vim.fn.matchfuzzy(fnames, cmdarg)
    end
  end

  vim.opt.findfunc = "v:lua.fd_find_files"
end

-- Find files via the "fd" command. This is an alternative to the "find"
-- command. For find we are using the "matchfuzzy()" function of Neovim to
-- filter the list of files returned by "fd". Here we are directly passing the
-- provided arguments to "fd" to filter the files.
--
-- If the search term is an existing file, we directly open this file.
-- Otherwise we populate the quickfix list with all files found be "fd" and the
-- search term.
vim.api.nvim_create_user_command("Find", function(opts)
  if vim.uv.fs_stat(opts.args) then
    vim.cmd.edit(opts.args)
  else
    local qflist = {}
    local files = vim.fn.systemlist(findCommand .. " " .. opts.args)

    for _, file in pairs(files) do
      table.insert(qflist, { filename = file, lnum = 1 })
    end

    vim.fn.setqflist(
      {},
      " ",
      { title = findCommand .. " " .. opts.args, items = qflist }
    )
    vim.cmd.copen()
  end
end, {
  complete = function(_, cmdline, _)
    local args = ""
    if #vim.fn.split(cmdline, " ") > 1 then
      args = table.concat(vim.fn.split(cmdline, " "), " ", 2)
    end

    local files = vim.fn.systemlist(findCommand .. args)
    return files
  end,
  nargs = "*",
})

-- Find recently opened files in the current working directory. We are using
-- the "oldfiles" command to get the list of recently opened files. Afterwards
-- we filter the files to only include those that are in the current working
-- directory. Finally we populate the quickfix list with the filtered files and
-- open the quickfix window.
vim.api.nvim_create_user_command("FindRecent", function()
  local qflist = {}
  local oldfiles = vim.api.nvim_command_output("oldfiles")
  local cwd = vim.fn.getcwd()

  for _, oldfile in pairs(vim.split(oldfiles, "\n")) do
    local file = oldfile:gsub(".*%s(.*)$", "%1")
    if file:sub(1, #cwd) == cwd then
      file = file:sub(#cwd + 2)

      if file ~= "" then
        table.insert(qflist, { filename = file, lnum = 1 })
      end
    end
  end

  vim.fn.setqflist({}, " ", { title = "Recent files", items = qflist })
  vim.cmd.copen()
end, { nargs = "*" })

-- Find all marks in the current working directory and show them in the quickfix
-- list.
vim.api.nvim_create_user_command("Marks", function()
  local qflist = {}
  local cwd = vim.pesc(vim.uv.cwd() .. "/")

  for idx = vim.fn.char2nr("A"), vim.fn.char2nr("Z") do
    local letter = vim.fn.nr2char(idx)
    local mark = vim.api.nvim_get_mark(letter, {})
    local filename = vim.fn.fnamemodify(mark[4], ":p")

    if filename:sub(1, #cwd) == cwd then
      filename = (filename:gsub("^" .. cwd, ""))

      if filename ~= "" then
        table.insert(
          qflist,
          { filename = filename, lnum = mark[1], col = mark[2], text = letter }
        )
      end
    end
  end

  vim.fn.setqflist({}, " ", { title = "Marks", items = qflist })
  vim.cmd.copen()
end, { nargs = "*" })

-- Add keymaps for all find related operations. This includes finding files via
-- the "find" and "Find" command (workspace or directory of the current file),
-- finding recent files, finding buffers and finding marks.
vim.keymap.set("n", "<leader>ff", ":find<space>")
vim.keymap.set("n", "<leader>fF", ":Find<space>")
vim.keymap.set("n", "<leader>fc", function()
  return ":find " .. vim.fn.expand("%:.:h") .. "/"
end, { expr = true })
vim.keymap.set("n", "<leader>fC", function()
  return ":Find " .. vim.fn.expand("%:.:h") .. "/"
end, { expr = true })
vim.keymap.set("n", "<leader>fr", "<cmd>FindRecent<cr>")
vim.keymap.set("n", "<leader>fb", ":buffer<space>")
vim.keymap.set("n", "<leader>fm", "<cmd>Marks<cr>")

--------------------------------------------------------------------------------
-- SEARCH THROUGH FILES
--------------------------------------------------------------------------------

-- If "rg" (ripgrep) is installed we use it to search though files with the
-- "grep" command.
if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg =
    "rg --vimgrep --smart-case --hidden --color=never --glob='!.git'"
  vim.opt.grepformat = "%f:%l:%c:%m"
end

-- Set keymaps for search operations. This includes searching through files in
-- the workspace or directory of the current file, searching for the word under
-- the cursor or visual selection and searching for todo comments.
vim.keymap.set("n", "<leader>ss", ":silent grep!<space>")
vim.keymap.set("n", "<leader>sc", function()
  return ":silent grep! --glob='" .. vim.fn.expand("%:.:h") .. "/**' "
end, { expr = true })
vim.keymap.set("n", "<leader>sw", ":silent grep!<space><c-r><c-w>")
vim.keymap.set("v", "<leader>sv", 'y:silent grep!<space><c-r>"')
vim.keymap.set(
  "n",
  "<leader>st",
  ":silent grep! -e='todo:' -e='warn:' -e='info:' -e='xxx:' -e='bug:' -e='fixme:' -e='fixit:' -e='bug:' -e='issue:'<cr>"
)

--------------------------------------------------------------------------------
-- REPLACE
--------------------------------------------------------------------------------

-- Replace in the current buffer or in all items in the quickfix list. Replace
-- in the current buffer also works for a visual selection.
vim.keymap.set(
  { "n", "v" },
  "<leader>rr",
  [[:%s///gcI<left><left><left><left><left>]]
)
vim.keymap.set(
  "n",
  "<leader>rw",
  [[:%s/\<<c-r><c-w>\>//gcI<left><left><left><left>]]
)
vim.keymap.set(
  "v",
  "<leader>rv",
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
  "v",
  "<leader>rV",
  [[y:cfdo %s/\V<c-r>"//gcI | update]]
    .. [[<left><left><left><left><left><left><left><left><left><left><left><left><left><left>]]
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

-- Add keymaps for easier acccess to the Quickfix list.
vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>")
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>")
vim.keymap.set("n", "<leader>qh", "<cmd>chistory<cr>")
vim.keymap.set("n", "<leader>qn", "<cmd>cnewer<cr>")
vim.keymap.set("n", "<leader>qp", "<cmd>colder<cr>")
vim.keymap.set("n", "<leader>q1", "<cmd>1chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q2", "<cmd>2chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q3", "<cmd>3chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q4", "<cmd>4chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q5", "<cmd>5chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q6", "<cmd>6chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q7", "<cmd>7chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q8", "<cmd>8chistory<cr> <bar> <cmd>copen<cr>")
vim.keymap.set("n", "<leader>q9", "<cmd>9chistory<cr> <bar> <cmd>copen<cr>")

--------------------------------------------------------------------------------
-- COLORSCHEME
--------------------------------------------------------------------------------

-- Use the built-in plugin manager to install the Catppuccin theme
--
-- See: https://neovim.io/doc/user/pack.html#_plugin-manager
vim.pack.add({
  {
    src = "https://github.com/catppuccin/nvim",
    name = "catppuccin",
  },
}, { load = true })

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
})

vim.cmd.colorscheme("catppuccin")

--------------------------------------------------------------------------------
-- TREESITTER
--------------------------------------------------------------------------------

-- Install the nvim-treesitter plugin and ensure that some parsers are always
-- installed. We also allow auto installing of additional parsers.
vim.pack.add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    name = "nvim-treesitter",
  },
}, { load = true })

require("nvim-treesitter.configs").setup({
  ensure_installed = {
    "bash",
    "css",
    "dart",
    "diff",
    "go",
    "helm",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "rust",
    "terraform",
    "tsx",
    "typescript",
    "yaml",
  },
  auto_install = true,
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true,
    disable = {
      "dart",
      "yaml",
    },
  },
})

vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup(
    "nvim-treesitter-pack-changed-update-handler",
    { clear = true }
  ),
  callback = function(event)
    if
      event.data.kind == "update"
      and event.data.spec.name == "nvim-treesitter"
    then
      vim.notify(
        "nvim-treesitter updated, running TSUpdate...",
        vim.log.levels.INFO
      )
      local ok = pcall(vim.cmd, "TSUpdate")
      if ok then
        vim.notify("TSUpdate completed successfully!", vim.log.levels.INFO)
      else
        vim.notify(
          "TSUpdate command not available yet, skipping",
          vim.log.levels.WARN
        )
      end
    end
  end,
})

--------------------------------------------------------------------------------
-- LSP
--------------------------------------------------------------------------------

-- Install the "helm-ls" plugin, which is required for the Helm Language Server
-- (helm_ls) to work properly.
--
-- See: https://github.com/mrjosh/helm-ls/blob/master/README.md#neovim
vim.pack.add({
  {
    src = "https://github.com/qvalentin/helm-ls.nvim",
    name = "helm-ls",
  },
}, { load = true })

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
  "copilot",
  "dartls",
  "denols",
  "dockerls",
  "docker_compose_language_service",
  "efm",
  "eslint",
  "golangci_lint_ls",
  "gopls",
  "helm_ls",
  "lua_ls",
  "marksman",
  "terraformls",
  "ts_ls",
  "yamlls",
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    local buffer = event.buf

    if client then
      -- Add additional keymaps to the default LSP keymaps.
      --
      -- See: https://neovim.io/doc/user/lsp.html#_global-defaults
      vim.keymap.set("n", "grf", vim.lsp.buf.format, { buffer = buffer })
      vim.keymap.set("n", "grq", vim.diagnostic.setqflist, { buffer = buffer })
      vim.keymap.set("n", "gry", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end, { buffer = buffer })
      vim.keymap.set("n", "gd", function()
        vim.lsp.buf.definition()
      end, { buffer = buffer })
      vim.keymap.set("n", "gD", function()
        vim.cmd([[ vsplit ]])
        vim.lsp.buf.definition()
      end, { buffer = buffer })

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
        vim.keymap.set("i", "<c-cr>", function()
          if not vim.lsp.inline_completion.get() then
            return "<c-cr>"
          end
        end, {
          expr = true,
          replace_keycodes = true,
        })
      end

      -- Add normal-mode keymappings for signature help.
      if client:supports_method("textDocument/signatureHelp") then
        vim.keymap.set("n", "<c-s>", function()
          vim.lsp.buf.signature_help()
        end)
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
  end,
})

--------------------------------------------------------------------------------
-- DIAGNOSTICS
--------------------------------------------------------------------------------

vim.diagnostic.config({
  underline = true,
  update_in_insert = false,
  virtual_text = {
    spacing = 4,
    source = "if_many",
    prefix = function(diagnostic)
      for d, icon in pairs(icons.diagnostics) do
        if diagnostic.severity == vim.diagnostic.severity[d:upper()] then
          return icon
        end
      end
    end,
    format = function(diagnostic)
      -- Replace newline and tab characters with space for more compact diagnostics.
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
  vim.fn.sign_define("DiagnosticSign" .. type, {
    name = "DiagnosticSign" .. type,
    text = icons.diagnostics[type],
    texthl = "Diagnostic" .. type,
  })
end

--------------------------------------------------------------------------------
-- STATUSLINE
--------------------------------------------------------------------------------

-- Install lualine as our statusline plugin.
vim.pack.add({
  {
    src = "https://github.com/nvim-lualine/lualine.nvim",
    name = "lualine",
  },
}, { load = true })

require("lualine").setup({
  options = {
    theme = "catppuccin",
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
    globalstatus = true,
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = {
      "branch",
      {
        "diff",
        symbols = {
          added = icons.git.added,
          modified = icons.git.modified,
          removed = icons.git.deleted,
        },
      },
      {
        "diagnostics",
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
    },
    lualine_c = {
      {
        -- Show tabs in the form "current/count", e.g. "1/2".
        function()
          local tab_count = vim.fn.tabpagenr("$")
          local current_tab = vim.fn.tabpagenr()
          return current_tab .. "/" .. tab_count
        end,
      },
      {
        "filename",
        file_status = true,
        newfile_status = false,
        path = 0,
        symbols = {
          modified = icons.git.modified,
          readonly = "󱈸",
          unnamed = icons.git.untracked,
          newfile = icons.git.added,
        },
      },
    },
    lualine_x = {
      "encoding",
      "fileformat",
      "filetype",
    },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

--------------------------------------------------------------------------------
-- GIT
--------------------------------------------------------------------------------

-- Install gitsigns and use our icons instead of the default ones.
vim.pack.add({
  {
    src = "https://github.com/lewis6991/gitsigns.nvim",
    name = "gitsigns",
  },
}, { load = true })

require("gitsigns").setup({
  signs = {
    add = { text = icons.git.added },
    change = { text = icons.git.modified },
    delete = { text = icons.git.deleted },
    topdelete = { text = icons.git.deleted },
    changedelete = { text = icons.git.modified },
    untracked = { text = icons.git.untracked },
  },
  signs_staged = {
    add = { text = icons.git.added },
    change = { text = icons.git.deleted },
    delete = { text = icons.git.deleted },
    topdelete = { text = icons.git.deleted },
    changedelete = { text = icons.git.modified },
    untracked = { text = icons.git.untracked },
  },
  preview_config = {
    border = "single",
  },
  on_attach = function(bufnr)
    -- Define keymaps for Git related actions provided by gitsigns.
    local gitsigns = require("gitsigns")

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
    vim.keymap.set("n", "<leader>gsb", function()
      gitsigns.blame_line({ full = true })
    end, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsB", gitsigns.blame, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsd", gitsigns.diffthis, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsD", function()
      gitsigns.diffthis("~")
    end, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsl", function()
      gitsigns.setloclist(bufnr)
    end, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gst", function()
      gitsigns.toggle_word_diff()
      gitsigns.toggle_deleted()
    end, { buffer = bufnr })
  end,
})

-- The "<leader>gsq" keymap populates the quickfix list with all git hunks. This
-- keymap is not defined in the on_attach function, so it is available globally.
vim.keymap.set("n", "<leader>gsq", "<cmd>:Gitsigns setqflist all<cr>")

-- The "GitDiff <base> <head>" command shows the diff between two branches via
-- gitsigns. It also populates the quickfix list with the hunks.
vim.api.nvim_create_user_command("GitDiff", function(opts)
  if #vim.fn.split(opts.args, " ") ~= 2 then
    return
  end

  local base = vim.fn.split(opts.args, " ")[1]
  local head = vim.fn.split(opts.args, " ")[2]

  local result = vim.system({ "git", "merge-base", base, head }):wait()
  if result.code ~= 0 then
    return
  end

  local commit = vim.fn.trim(result.stdout)

  local gitsigns = require("gitsigns")
  gitsigns.change_base(commit, true)
  gitsigns.setqflist("all")
end, { nargs = "*" })

--------------------------------------------------------------------------------
-- MULTICURSOR
--------------------------------------------------------------------------------

-- Lazy load the multicursor.nvim plugin, when a buffer is opened.
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup(
    "lazy-load-multicursor",
    { clear = true }
  ),
  once = true,
  callback = function()
    vim.pack.add({
      {
        src = "https://github.com/jake-stewart/multicursor.nvim",
        name = "multicursor",
      },
    }, { load = true })

    local mc = require("multicursor-nvim")
    mc.setup()

    -- Define keymaps for multicursor operations. A new cursor can be added
    -- using "Ctrl + k" / "Ctrl + j" for the line above / below, using
    -- "Ctrl + n" for the next word under the cursor "Ctrl + a" for all
    -- occurrences of the word under the cursor or using "Ctrl = m" for all
    -- provided matches.
    vim.keymap.set({ "n", "x" }, "<c-k>", function()
      mc.addCursor("k")
    end)
    vim.keymap.set({ "n", "x" }, "<c-j>", function()
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
-- AI
--------------------------------------------------------------------------------

vim.keymap.set("n", "<leader>co", "<cmd>CopilotChatOpen<cr>")
vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChatClose<cr>")
vim.keymap.set("n", "<leader>ct", "<cmd>CopilotChatToggle<cr>")
vim.keymap.set("n", "<leader>cs", "<cmd>CopilotChatStop<cr>")
vim.keymap.set("n", "<leader>cr", "<cmd>CopilotChatReset<cr>")

-- Lazy load the CopilotChat plugin, when a keymap from above or a command
-- starting with "CopilotChat" is used.
vim.api.nvim_create_autocmd("CmdUndefined", {
  group = vim.api.nvim_create_augroup(
    "lazy-load-copilotchat",
    { clear = true }
  ),
  pattern = { "CopilotChat*" },
  callback = function()
    vim.pack.add({
      {
        src = "https://github.com/nvim-lua/plenary.nvim",
      },
      {
        src = "https://github.com/CopilotC-Nvim/CopilotChat.nvim",
        name = "CopilotChat",
      },
    }, { load = true })

    require("CopilotChat").setup({
      model = "claude-3.7-sonnet",
      agent = "copilot",
    })
  end,
  once = true,
})
