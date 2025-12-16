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
  github = {
    unknown = "",
    pr = "",
    issue = "",
    release = "",
    workflow = "",
    commit = "",
    gist = "",
    discussion = "",
  },
  notifications = {
    unread = "",
    read = "",
  },
}

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

vim.opt.background = "dark"
vim.opt.shada = "!,'1000,<50,s10,h"
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

-- Surround the visual selection with parentheses, brackets, braces or quotes.
vim.keymap.set("x", "gs(", "<esc>`>a)<esc>`<i(<esc>")
vim.keymap.set("x", "gs)", "<esc>`>a)<esc>`<i(<esc>")
vim.keymap.set("x", "gs{", "<esc>`>a}<esc>`<i{<esc>")
vim.keymap.set("x", "gs}", "<esc>`>a}<esc>`<i{<esc>")
vim.keymap.set("x", "gs[", "<esc>`>a]<esc>`<i[<esc>")
vim.keymap.set("x", "gs]", "<esc>`>a]<esc>`<i[<esc>")
vim.keymap.set("x", "gs<", "<esc>`>a><esc>`<i<<esc>")
vim.keymap.set("x", "gs>", "<esc>`>a><esc>`<i<<esc>")
vim.keymap.set("x", 'gs"', '<esc>`>a"<esc>`<i"<esc>')
vim.keymap.set("x", "gs'", "<esc>`>a'<esc>`<i'<esc>")
vim.keymap.set("x", "gs`", "<esc>`>a`<esc>`<i`<esc>")
vim.keymap.set("x", "gs*", "<esc>`>a*<esc>`<i*<esc>")
vim.keymap.set("x", "gs_", "<esc>`>a_<esc>`<i_<esc>")

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
-- UTILS
--------------------------------------------------------------------------------

-- Convert ISO 8601 timestamp to relative time
--
-- See: https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/gh/item.lua#L15
-- See: https://github.com/folke/snacks.nvim/blob/fe7cfe9800a182274d0f868a74b7263b8c0c020b/lua/snacks/picker/util/init.lua#L414
local function format_relative_time(s)
  local year, month, day, hour, min, sec =
    s:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z$")
  if not year then
    return
  end
  local t = os.time({
    year = assert(tonumber(year), "invalid year in timestamp: " .. s),
    month = assert(tonumber(month), "invalid month in timestamp: " .. s),
    day = assert(tonumber(day), "invalid day in timestamp: " .. s),
    hour = assert(tonumber(hour), "invalid hour in timestamp: " .. s),
    min = assert(tonumber(min), "invalid minute in timestamp: " .. s),
    sec = assert(tonumber(sec), "invalid second in timestamp: " .. s),
    isdst = false,
  })

  -- Calculate UTC offset
  local now = os.time()
  local utc_date = os.date("!*t", now)
  utc_date.isdst = false
  local time = t + os.difftime(now, os.time(utc_date))

  local delta = os.time() - time
  local tpl = {
    { 1, 60, "just now", "just now" },
    { 60, 3600, "a minute ago", "%d minutes ago" },
    { 3600, 3600 * 24, "an hour ago", "%d hours ago" },
    { 3600 * 24, 3600 * 24 * 7, "yesterday", "%d days ago" },
    { 3600 * 24 * 7, 3600 * 24 * 7 * 4, "a week ago", "%d weeks ago" },
  }
  for _, v in ipairs(tpl) do
    if delta < v[2] then
      local value = math.floor(delta / v[1] + 0.5)
      return value == 1 and v[3] or v[4]:format(value)
    end
  end
  if os.date("%Y", time) == os.date("%Y") then
    return os.date("%b %d", time)
  end
  return os.date("%b %d, %Y", time)
end

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
    snacks = {
      enabled = false,
      indent_scope_color = "",
    },
    treesitter = true,
  },
  custom_highlights = function(colors)
    return {
      Pmenu = { bg = colors.mantle },
      PmenuBorder = { bg = colors.mantle, fg = colors.blue },
    }
  end,
})

vim.cmd.colorscheme("catppuccin")

--------------------------------------------------------------------------------
-- SNACKS
--------------------------------------------------------------------------------

vim.pack.add({
  {
    src = "https://github.com/folke/snacks.nvim",
    name = "snacks",
    version = "main",
  },
}, { confirm = false, load = true })

local fd_args = {
  "--exclude",
  ".git",
  "--exclude",
  "node_modules",
  "--exclude",
  "dist",
  "--exclude",
  ".DS_Store",
}

local rg_args = {
  "--glob=!.git",
  "--glob=!node_modules",
  "--glob=!dist",
  "--glob=!.DS_Store",
}

require("snacks").setup({
  -- Deal with big files. Enable when file is larger then 1MB and show
  -- notification when big file detected.
  bigfile = {
    enabled = true,
    notify = true,
    size = 3 * 1024 * 1024,
  },
  -- GitHub CLI integration.
  gh = {
    enabled = true,
  },
  -- Open the current file, branch, commit, or repo in a browser (e.g. GitHub,
  -- GitLab, Bitbucket).
  gitbrowse = {
    enabled = true,
  },
  -- Visualize indent guides and scopes based on treesitter or indent.
  indent = {
    enabled = true,
    animate = {
      enabled = false,
    },
  },
  -- Better "vim.ui.input".
  input = {
    enabled = true,
  },
  -- Picker for selecting items such as files, grep results, buffers, marks,
  -- etc.
  picker = {
    enabled = true,
    ui_select = true,
    icons = {
      git = {
        enabled = true,
        commit = icons.git.commit,
        staged = icons.git.staged,
        added = icons.git.added,
        deleted = icons.git.deleted,
        ignored = icons.git.ignored,
        modified = icons.git.modified,
        renamed = icons.git.renamed,
        unmerged = icons.git.unmerged,
        untracked = icons.git.untracked,
      },
      diagnostics = icons.diagnostics,
      kinds = icons.kinds,
    },
    win = {
      list = {
        wo = {
          relativenumber = true,
        },
      },
    },
    sources = {
      explorer = {
        auto_close = true,
        hidden = true,
        layout = {
          preset = "default",
          preview = false,
        },
        actions = {
          -- Overwrite the "explorer_yank" command to provide more options for
          -- yanking file information. By default the command would copy the
          -- full path ot the file to the clipboard. Now we can choose what path
          -- should be copied.
          explorer_yank_path = {
            action = function(_, item)
              if not item then
                return
              end

              local vals = {
                ["basename"] = vim.fn.fnamemodify(item.file, ":t:r"),
                ["extension"] = vim.fn.fnamemodify(item.file, ":t:e"),
                ["filename"] = vim.fn.fnamemodify(item.file, ":t"),
                ["path"] = item.file,
                ["path (cwd)"] = vim.fn.fnamemodify(item.file, ":."),
                ["path (home)"] = vim.fn.fnamemodify(item.file, ":~"),
                ["uri"] = vim.uri_from_fname(item.file),
              }

              local options = vim.tbl_filter(function(val)
                return vals[val] ~= ""
              end, vim.tbl_keys(vals))
              if vim.tbl_isempty(options) then
                return
              end
              table.sort(options)
              vim.ui.select(options, {
                prompt = "Choose to copy to clipboard:",
                format_item = function(list_item)
                  return ("%s: %s"):format(list_item, vals[list_item])
                end,
              }, function(choice)
                local result = vals[choice]
                if result then
                  vim.fn.setreg("+", result)
                  vim.notify("Yanked " .. result, vim.log.levels.INFO)
                end
              end)
            end,
          },
          -- Search in the selected directory using "rg" (ripgrep).
          explorer_search_in_directory = {
            action = function(_, item)
              if not item then
                return
              end
              local dir = vim.fn.fnamemodify(item.file, ":p:h")
              Snacks.picker.grep({
                cwd = dir,
                cmd = "rg",
                args = rg_args,
                show_empty = true,
                hidden = true,
                ignored = false,
                follow = false,
                supports_live = true,
              })
            end,
          },
          -- Show diff between two selected files in a new tab. The files which
          -- should be compared must be selected using "tab" or "shift+tab".
          explorer_diff = {
            action = function(picker)
              picker:close()
              local sel = picker:selected()
              if #sel > 0 and sel then
                vim.cmd("tabnew")
                vim.cmd("DiffTool " .. sel[1].file .. " " .. sel[2].file)
                return
              end
            end,
          },
        },
        win = {
          list = {
            keys = {
              ["Y"] = "explorer_yank_path",
              ["s"] = "explorer_search_in_directory",
              ["D"] = "explorer_diff",
            },
          },
        },
      },
      files = {
        cmd = "fd",
        args = fd_args,
        show_empty = true,
        hidden = true,
        ignored = false,
        follow = false,
        supports_live = true,
      },
      grep = {
        cmd = "rg",
        args = rg_args,
        hidden = true,
        ignored = false,
        follow = false,
        supports_live = true,
      },
      marks = {
        global = true,
        ["local"] = true,
        win = {
          input = {
            keys = {
              ["<c-x>"] = { "mark_delete", mode = { "n", "i" } },
            },
          },
        },
      },
    },
  },
  -- When doing "nvim somefile.txt", it will render the file as quickly as
  -- possible, before loading your plugins.
  quickfile = {
    enabled = true,
  },
})

--------------------------------------------------------------------------------
-- EXPLORER
--------------------------------------------------------------------------------

-- Show file explorer, which can be used to navigate the file system. The
-- explorer also allows to perform file operations such as create, delete, move,
-- etc.
vim.keymap.set("n", "<leader>ee", function()
  Snacks.picker.explorer()
end)

-- Keymap to create a new file and open it in insert mode.
vim.keymap.set("n", "<leader>en", function()
  Snacks.input({
    prompt = "File Name",
    default = "untitled",
  }, function(value)
    vim.cmd("e " .. value .. " | startinsert")
  end)
end)

-- Keymap to save a file without running any auto commands and with creating
-- directories.
vim.keymap.set("n", "<leader>ew", "<cmd>noautocmd write ++p<cr>")

--------------------------------------------------------------------------------
-- FIND FILES
--------------------------------------------------------------------------------

local find_command =
  "fd --full-path --hidden --color never --type f --exclude .git --exclude node_modules --exclude dist --exclude .DS_Store"

-- Use "fd" to find files with the "find" command. Together with the
-- "matchfuzzy()" function this should replace any external fuzzy finder plugin.
function _G.fd_find_files(cmdarg, _)
  local fnames = vim.fn.systemlist(find_command)

  if #cmdarg == 0 then
    return fnames
  else
    return vim.fn.matchfuzzy(fnames, cmdarg)
  end
end

vim.opt.findfunc = "v:lua.fd_find_files"

-- Keymaps for finding files, buffers, recent files, etc. using the Snacks
-- picker.
vim.keymap.set("n", "<leader>ff", function()
  Snacks.picker.files()
end)
vim.keymap.set("n", "<leader>fs", function()
  Snacks.picker.smart({ filter = { cwd = true } })
end)
vim.keymap.set("n", "<leader>fb", function()
  Snacks.picker.buffers()
end)
vim.keymap.set("n", "<leader>fr", function()
  Snacks.picker.recent({ filter = { cwd = true } })
end)
vim.keymap.set("n", "<leader>fu", function()
  Snacks.picker.undo()
end)
vim.keymap.set("n", "<leader>fm", function()
  Snacks.picker.marks()
end)
vim.keymap.set("n", "<leader>fd", function()
  Snacks.picker.diagnostics_buffer()
end)
vim.keymap.set("n", "<leader>fD", function()
  Snacks.picker.diagnostics()
end)

--------------------------------------------------------------------------------
-- SEARCH THROUGH FILES
--------------------------------------------------------------------------------

-- Use "rg" (ripgrep) to search though files with the "grep" command.
vim.opt.grepprg =
  "rg --vimgrep --smart-case --hidden --color=never --glob='!.git' --glob='!node_modules' --glob='!dist' --glob='!.DS_Store'"
vim.opt.grepformat = "%f:%l:%c:%m"

-- Keymaps for searching through files using the Snacks picker.
vim.keymap.set("n", "<leader>ss", function()
  Snacks.picker.grep()
end)
vim.keymap.set("n", "<leader>s/", function()
  Snacks.picker.grep_buffers()
end)
vim.keymap.set({ "n", "x" }, "<leader>sw", function()
  Snacks.picker.grep_word()
end)
vim.keymap.set({ "n", "x" }, "<leader>st", function()
  Snacks.picker.grep({
    regex = true,
    cmd = "rg",
    args = rg_args,
    format = "file",
    search = function()
      return "todo:|warn:|info:|xxx:|bug:|fixme:|fixit:|issue:"
    end,
    live = false,
    supports_live = true,
  })
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
ts.install(ts_parsers)

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
  "pyright",
  "terraformls",
  "ts_ls",
  "yamlls",
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    local buffer = event.buf

    if client then
      -- Add additional keymaps to the default LSP keymaps and overwrite some
      -- default keymaps to use Snacks functionalities. Some defaults are
      -- overridden to show a picker, so that the locations can be opened in a
      -- new tab, split, etc.
      --
      -- See: https://neovim.io/doc/user/lsp.html#_global-defaults
      vim.keymap.set("n", "grf", function()
        vim.lsp.buf.format({
          timeout_ms = 60000,
        })
      end, { buffer = buffer })
      vim.keymap.set("n", "gd", function()
        Snacks.picker.lsp_definitions({ auto_confirm = false })
      end, { buffer = buffer })
      vim.keymap.set("n", "gD", function()
        Snacks.picker.lsp_declarations({ auto_confirm = false })
      end)
      vim.keymap.set("n", "gri", function()
        Snacks.picker.lsp_implementations({ auto_confirm = false })
      end)
      vim.keymap.set("n", "grr", function()
        Snacks.picker.lsp_references({ auto_confirm = false })
      end)
      vim.keymap.set("n", "<leader>grt", function()
        Snacks.picker.lsp_type_definitions({ auto_confirm = false })
      end)
      vim.keymap.set("n", "gO", function()
        Snacks.picker.lsp_symbols()
      end)
      vim.keymap.set("n", "grh", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
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
    version = "master",
  },
}, { confirm = false, load = true })

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
    version = "main",
  },
}, { confirm = false, load = true })

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

    -- Git diff.
    vim.keymap.set("n", "<leader>gsd", gitsigns.diffthis, { buffer = bufnr })
    vim.keymap.set("n", "<leader>gsD", function()
      gitsigns.diffthis("~")
    end, { buffer = bufnr })

    -- Toggle word diff and deleted lines.
    vim.keymap.set("n", "<leader>gst", function()
      gitsigns.toggle_word_diff()
      gitsigns.toggle_deleted()
    end, { buffer = bufnr })
  end,
})

-- Git blame line via Snacks.
--
-- We are using the gitsigns prefix, also when we are using Snacks for blaming
-- lines.
vim.keymap.set("n", "<leader>gsb", function()
  Snacks.git.blame_line()
end)

-- Find related Git actions powered by the Snacks picker. It is possible to find
-- files, diffs, branches, commits, stashed and status entries.
vim.keymap.set("n", "<leader>gff", function()
  Snacks.picker.git_files()
end)
vim.keymap.set("n", "<leader>gfd", function()
  Snacks.picker.git_diff()
end)
vim.keymap.set("n", "<leader>gfb", function()
  Snacks.picker.git_branches()
end)
vim.keymap.set("n", "<leader>gfl", function()
  Snacks.picker.git_log_file()
end)
vim.keymap.set("n", "<leader>gfL", function()
  Snacks.picker.git_log()
end)
vim.keymap.set("n", "<leader>gfs", function()
  Snacks.picker.git_status()
end)
vim.keymap.set("n", "<leader>gfS", function()
  Snacks.picker.git_stash()
end)

-- DiffTool is the newly built-in diff tool of Neovim.
--
-- DiffTool is configured as "git difftool" and can be used as follows:
--   - git difftool -d
--   - git difftool -d origin/HEAD...HEAD
vim.cmd([[packadd nvim.difftool]])

-- Custom Snacks picker to find all merge conflicts in the current Git
-- repository.
--
-- See: https://github.com/git/git/blob/215033b3ac599432a17d58f18a92b356d98354a9/contrib/git-jump/git-jump#L59
vim.keymap.set("n", "<leader>gfm", function()
  local items = {}
  local files = vim.fn.systemlist(
    "git ls-files -u | perl -pe 's/^.*?\t//' | sort -u | while IFS= read fn; do grep -Hn '^<<<<<<<' \"$fn\"; done"
  )

  for idx, file in pairs(files) do
    local parts = vim.fn.split(file, ":")
    table.insert(items, {
      idx = idx,
      text = parts[1] .. ":" .. parts[2],
      file = parts[1],
      cwd = Snacks.git.get_root(),
      pos = { tonumber(parts[2]), 0 },
    })
  end

  Snacks.picker({
    title = "Git Merge Conflicts",
    items = items,
  })
end)

-- Open the position under the cursor on GitHub, GitLab, Bitbucket, etc.
vim.keymap.set("n", "<leader>gb", function()
  Snacks.gitbrowse()
end)

--------------------------------------------------------------------------------
-- GITHUB
--------------------------------------------------------------------------------

-- Fetch notifications from GitHub and show them via the Snacks picker. Issues
-- and PRs can be opened via Snacks. Discussions are opened in the browser.
vim.api.nvim_create_user_command("GitHubNotifications", function(opts)
  -- Fetch notifications from GitHub using the "gh" command-line tool and handle
  -- any errors.
  local output =
    vim.fn.system(string.format("gh-notifications '%s'", opts.args))

  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Failed to fetch GitHub notifications: " .. output,
      vim.log.levels.ERROR
    )
    return
  end

  local ok, notifications = pcall(vim.fn.json_decode, output)
  if not ok or type(notifications) ~= "table" then
    vim.notify("Failed to parse GitHub notifications", vim.log.levels.ERROR)
    return
  end

  if #notifications == 0 then
    vim.notify("No GitHub notifications found", vim.log.levels.INFO)
    return
  end

  -- Prepare the items for the Snacks picker and format them nicely.
  local items = {}
  for idx, notification in ipairs(notifications) do
    local item = notification
    item.idx = idx
    item.text = item.title
    item.preview = {
      text = item.summaryItemBody,
      ft = "markdown",
    }
    item.relativeLastUpdatedAt = format_relative_time(item.lastUpdatedAt)
    item.repo = item.url:match("github.com/([^/]+/[^/]+)")
    table.insert(items, item)
  end

  -- Open the Snacks picker with the formatted notification items and format the
  -- items nicely.
  Snacks.picker({
    title = "GitHub Notifications",
    layout = {
      preset = "default",
      preview = false,
    },
    preview = "preview",
    items = items,
    format = function(item, _)
      -- See ": lua Snacks.picker.highlights({pattern = "hl_group:^Snacks"})"
      local icon = { icons.notifications.read, "SnacksPickerGitStatusAdded" }
      if item.isUnread then
        icon = { icons.notifications.unread, "SnacksPickerGitStatusAdded" }
      end

      local type_icon = { icons.github.unknown, "SnacksPickerGitStatusIgnored" }
      if item.subject.__typename == "PullRequest" then
        type_icon = { icons.github.pr, "SnacksPickerGitStatusIgnored" }
        if item.subject.pullRequestState ~= nil then
          if item.subject.isDraft then
            type_icon = { icons.github.pr, "SnacksPickerGitStatusIgnored" }
          elseif item.subject.pullRequestState == "OPEN" then
            type_icon = { icons.github.pr, "SnacksPickerGitStatusAdded" }
          elseif item.subject.pullRequestState == "CLOSED" then
            type_icon = { icons.github.pr, "SnacksPickerGitStatusUnmerged" }
          elseif item.subject.pullRequestState == "MERGED" then
            type_icon = { icons.github.pr, "SnacksPickerGitStatus" }
          end
        end
      elseif item.subject.__typename == "Issue" then
        type_icon = { icons.github.issue, "SnacksPickerGitStatusIgnored" }
        if item.subject.issueState ~= nil then
          if item.subject.issueState == "OPEN" then
            type_icon = { icons.github.issue, "SnacksPickerGitStatusAdded" }
          elseif item.subject.issueState == "CLOSED" then
            type_icon = { icons.github.issue, "SnacksPickerGitStatusUnmerged" }
          end
        end
      elseif item.subject.__typename == "Release" then
        type_icon = { icons.github.release, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "WokflowRun" then
        type_icon = { icons.github.workflow, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "CheckSuite" then
        type_icon = { icons.github.workflow, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "Commit" then
        type_icon = { icons.github.commit, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "Gist" then
        type_icon = { icons.github.gist, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "TeamDiscussion" then
        type_icon = { icons.github.discussion, "SnacksPickerGitStatusIgnored" }
      elseif item.subject.__typename == "Discussion" then
        type_icon = { icons.github.discussion, "SnacksPickerGitStatusIgnored" }
      end

      return {
        icon,
        { " ", "SnacksPickerGitStatusIgnored" },
        type_icon,
        { " [", "SnacksPickerGitStatusIgnored" },
        { item.subject.__typename, "SnacksPickerGitType" },
        { "] ", "SnacksPickerGitStatusIgnored" },
        { item.repo, "SnacksPickerGitStatusIgnored" },
        { ": ", "SnacksPickerGitStatusIgnored" },
        { item.title, "SnacksPickerGitScope" },
        { " (", "SnacksPickerGitStatusIgnored" },
        { item.reason:lower():gsub("_", " "), "SnacksPickerGitStatusIgnored" },
        { " - ", "SnacksPickerGitStatusIgnored" },
        { item.relativeLastUpdatedAt, "SnacksPickerGitStatusIgnored" },
        { ")", "SnacksPickerGitStatusIgnored" },
      }
    end,
    confirm = function(picker, item)
      -- If the item is an issue or pull request, we try to open it via Snacks,
      -- otherwise we open it in the browser.
      if
        item.subject.__typename == "Issue"
        or item.subject.__typename == "PullRequest"
      then
        local itemType = item.subject.__typename == "Issue" and "issue" or "pr"

        picker:close()
        Snacks.picker.gh_actions({
          type = itemType,
          repo = item.repo,
          number = item.subject.number,
        })
      else
        vim.fn.system(string.format("open '%s'", item.url))
      end
    end,
    actions = {
      picker_yank_url = function(_, item)
        if not item then
          return
        end

        vim.fn.setreg("+", item.url)
        vim.notify("Yanked " .. item.url, vim.log.levels.INFO)
      end,
      picker_mark_as_read = function(_, item)
        if not item then
          return
        end

        local readoutput = vim.fn.system(
          string.format(
            "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsRead(input: {id: $notificationId}) { success } }'",
            item.id
          )
        )
        if vim.v.shell_error ~= 0 then
          vim.notify(
            "Failed to mark as read: " .. readoutput,
            vim.log.levels.ERROR
          )
          return
        end

        vim.notify("Marked as read: " .. item.title, vim.log.levels.INFO)
      end,
      picker_mark_as_unread = function(_, item)
        if not item then
          return
        end

        local readoutput = vim.fn.system(
          string.format(
            "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsUnread(input: {id: $notificationId}) { success } }'",
            item.id
          )
        )
        if vim.v.shell_error ~= 0 then
          vim.notify(
            "Failed to mark as unread: " .. readoutput,
            vim.log.levels.ERROR
          )
          return
        end

        vim.notify("Marked as unread " .. item.title, vim.log.levels.INFO)
      end,
      picker_mark_as_done = function(_, item)
        if not item then
          return
        end

        local readoutput = vim.fn.system(
          string.format(
            "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsDone(input: {id: $notificationId}) { success } }'",
            item.id
          )
        )
        if vim.v.shell_error ~= 0 then
          vim.notify(
            "Failed to mark as done: " .. readoutput,
            vim.log.levels.ERROR
          )
          return
        end

        vim.notify("Marked as done: " .. item.title, vim.log.levels.INFO)
      end,
      picker_mark_as_undone = function(_, item)
        if not item then
          return
        end

        local readoutput = vim.fn.system(
          string.format(
            "gh api graphql -F notificationId=\"%s\" --raw-field query='mutation($notificationId: ID!) { markNotificationAsUndone(input: {id: $notificationId}) { success } }'",
            item.id
          )
        )
        if vim.v.shell_error ~= 0 then
          vim.notify(
            "Failed to mark as undone: " .. readoutput,
            vim.log.levels.ERROR
          )
          return
        end

        vim.notify("Marked as undone: " .. item.title, vim.log.levels.INFO)
      end,
    },
    win = {
      input = {
        keys = {
          ["y"] = "picker_yank_url",
          ["Y"] = "picker_yank_url",
          ["r"] = "picker_mark_as_read",
          ["R"] = "picker_mark_as_unread",
          ["d"] = "picker_mark_as_done",
          ["D"] = "picker_mark_as_undone",
        },
      },
    },
  })
end, {
  nargs = "*",
})

vim.keymap.set("n", "<leader>ghn", "<cmd>GitHubNotifications -is:done<cr>")

-- Fetch search results from GitHub and show them via the Snacks picker. Issues
-- and PRs are opened via Snacks.
vim.api.nvim_create_user_command("GitHubSearch", function(opts)
  -- Fetch search results from GitHub using the "gh" command-line tool and
  -- handle any errors.
  local output = vim.fn.system(
    string.format(
      "gh search issues --include-prs --limit 100 --json author,body,isPullRequest,number,repository,state,title,updatedAt,url %s",
      opts.args
    )
  )
  if vim.v.shell_error ~= 0 then
    vim.notify(
      "Failed to fetch GitHub search results: " .. output,
      vim.log.levels.ERROR
    )
    return
  end

  local ok, results = pcall(vim.fn.json_decode, output)
  if not ok or type(results) ~= "table" then
    vim.notify("Failed to parse GitHub search results", vim.log.levels.ERROR)
    return
  end

  if #results == 0 then
    vim.notify("No GitHub search results found", vim.log.levels.INFO)
    return
  end

  -- Prepare the items for the Snacks picker and format them nicely.
  local items = {}
  for idx, result in ipairs(results) do
    local item = result
    item.idx = idx
    item.text = result.title
    item.preview = {
      text = item.body,
      ft = "markdown",
    }
    item.relativeUpdatedAt = format_relative_time(item.updatedAt)
    table.insert(items, item)
  end

  -- Open the Snacks picker with the formatted notification items and format the
  -- items nicely.
  Snacks.picker({
    title = "GitHub Search Results",
    layout = {
      preset = "default",
      preview = false,
    },
    preview = "preview",
    items = items,
    format = function(item, _)
      -- See ": lua Snacks.picker.highlights({pattern = "hl_group:^Snacks"})"
      local type_icon = { icons.github.unknown, "SnacksPickerGitStatusIgnored" }

      if item.isPullRequest then
        if item.state == "open" then
          type_icon = { icons.github.pr, "SnacksPickerGitStatusAdded" }
        elseif item.state == "closed" then
          type_icon = { icons.github.pr, "SnacksPickerGitStatusUnmerged" }
        elseif item.state == "merged" then
          type_icon = { icons.github.pr, "SnacksPickerGitStatus" }
        end
      else
        if item.state == "open" then
          type_icon = { icons.github.issue, "SnacksPickerGitStatusAdded" }
        elseif item.state == "closed" then
          type_icon = { icons.github.issue, "SnacksPickerGitStatusUnmerged" }
        end
      end

      return {
        type_icon,
        { " [", "SnacksPickerGitStatusIgnored" },
        { "#" .. item.number, "SnacksPickerGitType" },
        { "] ", "SnacksPickerGitStatusIgnored" },
        { item.repository.nameWithOwner, "SnacksPickerGitStatusIgnored" },
        { ": ", "SnacksPickerGitStatusIgnored" },
        { item.title, "SnacksPickerGitScope" },
        { " (by ", "SnacksPickerGitStatusIgnored" },
        { item.author.login, "SnacksPickerGitStatusIgnored" },
        { " - ", "SnacksPickerGitStatusIgnored" },
        { item.relativeUpdatedAt, "SnacksPickerGitStatusIgnored" },
        { ")", "SnacksPickerGitStatusIgnored" },
      }
    end,
    confirm = function(picker, item)
      local item_type = item.isPullRequest and "pr" or "issue"

      picker:close()
      Snacks.picker.gh_actions({
        type = item_type,
        repo = item.repository.nameWithOwner,
        number = item.number,
      })
    end,
    actions = {
      picker_yank_url = function(_, item)
        if not item then
          return
        end

        vim.fn.setreg("+", item.url)
        vim.notify("Yanked " .. item.url, vim.log.levels.INFO)
      end,
    },
    win = {
      input = {
        keys = {
          ["y"] = "picker_yank_url",
          ["Y"] = "picker_yank_url",
        },
      },
    },
  })
end, {
  nargs = "*",
})

-- Show pull requests involving, created by, assigned to, mentioning or
-- requesting a review from me.
vim.keymap.set(
  "n",
  "<leader>ghpi",
  "<cmd>GitHubSearch is:pr is:open involves:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghpc",
  "<cmd>GitHubSearch is:pr is:open author:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghpa",
  "<cmd>GitHubSearch is:pr is:open assignee:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghpm",
  "<cmd>GitHubSearch is:pr is:open mentions:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghpr",
  "<cmd>GitHubSearch is:pr is:open review-requested:ricoberger<cr>"
)

-- Show issues involving, created by, assigned to or mentioning me.
vim.keymap.set(
  "n",
  "<leader>ghii",
  "<cmd>GitHubSearch is:issue is:open involves:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghic",
  "<cmd>GitHubSearch is:issue is:open author:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghia",
  "<cmd>GitHubSearch is:issue is:open assignee:ricoberger<cr>"
)
vim.keymap.set(
  "n",
  "<leader>ghim",
  "<cmd>GitHubSearch is:issue is:open mentions:ricoberger<cr>"
)

--------------------------------------------------------------------------------
-- MISC
--------------------------------------------------------------------------------

-- Toggle zen mode for distraction-free coding.
vim.keymap.set("n", "<leader>mz", function()
  Snacks.zen()
end)

-- Toggle spell checking for the current buffer. If spell checking is already
-- enabled with the given language then it will be disabled.
local function toggle_spell(lang)
  local spell_on = vim.opt_local.spell:get()
  local current_langs = vim.opt_local.spelllang:get()
  local current_lang = spell_on and current_langs[1] or nil

  if current_lang == lang then
    vim.opt_local.spell = false
    return
  end

  vim.opt_local.spell = true
  vim.opt_local.spelllang = { lang }
end

vim.keymap.set("n", "<leader>ms", function()
  toggle_spell("en_us")
end)

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
        version = "main",
      },
    }, { confirm = false, load = true })

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

vim.pack.add({
  {
    src = "https://github.com/folke/sidekick.nvim",
    name = "sidekick",
    version = "main",
  },
}, { confirm = false, load = true })

-- Setup sidekick.nvim for next edit suggestions and AI chat. The next edit
-- suggestions are integrated with the GitHub Copilot LSP server. The AI chat
-- uses the GitHub Copilot CLI tool as backend.
require("sidekick").setup({
  nes = {
    diff = {
      inline = "chars",
    },
  },
  cli = {
    win = {
      keys = {
        stopinsert = { "<esc><esc>", "stopinsert", mode = "t" },
        hide_n = { "q", "hide", mode = "n" },
        hide_t = { "<c-q>", "hide" },
        win_p = { "<c-w>p", "blur" },
        blur = { "<c-o>", "blur" },
        prompt = { "<c-p>", "prompt" },
      },
    },
    mux = {
      backend = "tmux",
      enabled = false,
    },
    tools = {
      copilot = {
        cmd = { "copilot", "--banner" },
        url = "https://github.com/github/copilot-cli",
      },
    },
  },
})

-- Use Tab to jump to the next edit suggestion and to to apply it. If there is
-- no suggestion available Tab works as normal.
vim.keymap.set({ "i", "n" }, "<tab>", function()
  if require("sidekick").nes_jump_or_apply() then
    return
  end

  return "<tab>"
end, { expr = true })

-- Add keymaps for AI chat related actions. The "Space + aa" can be used toggle
-- the AI chat window and focuses it. The "Space + ap" keymap can be used to
-- select a predifined prompt / context.
vim.keymap.set({ "n", "x" }, "<leader>aa", function()
  require("sidekick.cli").toggle({ name = "copilot", focus = true })
end)
vim.keymap.set({ "n", "x" }, "<leader>ap", function()
  require("sidekick.cli").prompt()
end)

-- Add keymaps for next edit suggestion actions. The "Space + an" keymap can be
-- used to toggle the next edit suggestion feature.
vim.keymap.set({ "n" }, "<leader>an", function()
  require("sidekick.nes").toggle()
end)

--------------------------------------------------------------------------------
-- NOTES
--------------------------------------------------------------------------------

local notes_dir = "/Users/ricoberger/Documents/GitHub/ricoberger/notes"

vim.keymap.set("n", "<leader>nd", function()
  local date = vim.fn.strftime("%Y/%m/%Y-%m-%d")

  if vim.uv.fs_stat(notes_dir .. "/daily/" .. date .. ".md") then
    vim.cmd("e " .. notes_dir .. "/daily/" .. date .. ".md")
  else
    vim.cmd("e " .. notes_dir .. "/daily/" .. date .. ".md")
    vim.cmd("r " .. notes_dir .. "/daily/template.md")
  end
end)

vim.keymap.set("n", "<leader>ny", function()
  local date = vim.fn.strftime("%Y/%m/%Y-%m-%d", vim.fn.localtime() - 3600 * 24)
  vim.cmd("e " .. notes_dir .. "/daily/" .. date .. ".md")
end)

vim.keymap.set("n", "<leader>nf", function()
  Snacks.picker.files({
    cwd = notes_dir,
    cmd = "fd",
    args = fd_args,
    show_empty = true,
    hidden = true,
    ignored = false,
    follow = false,
    supports_live = true,
  })
end)

vim.keymap.set("n", "<leader>ns", function()
  Snacks.picker.grep({
    cwd = notes_dir,
    cmd = "rg",
    args = rg_args,
    hidden = true,
    ignored = false,
    follow = false,
    supports_live = true,
  })
end)

vim.keymap.set("n", "<leader>nt", function()
  Snacks.picker.grep({
    cwd = notes_dir,
    regex = true,
    cmd = "rg",
    args = rg_args,
    format = "file",
    search = function()
      return "- \\[ \\] .*"
    end,
    live = false,
    supports_live = true,
  })
end)

vim.keymap.set("n", "<leader>nk", function()
  Snacks.picker.grep({
    cwd = notes_dir,
    regex = true,
    cmd = "rg",
    args = rg_args,
    format = "file",
    search = function()
      return "^tags: \\[(.*)\\]$"
    end,
    live = false,
    supports_live = true,
  })
end)

vim.keymap.set("n", "<leader>ne", function()
  Snacks.picker.explorer({
    cwd = notes_dir,
  })
end)
