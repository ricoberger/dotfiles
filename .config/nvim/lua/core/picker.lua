local M = {}

local state = {
  buf = nil,
  win = nil,
  job = nil,
}

-- Catppuccin Macchiato colors for fzf, so it matches the terminal window.
local FZF_COLORS = table.concat({
  "--color=bg+:#363a4f,bg:#24273a,spinner:#f4dbd6,hl:#ed8796",
  "fg:#cad3f5,header:#ed8796,info:#c6a0f6,pointer:#f4dbd6",
  "marker:#f4dbd6,fg+:#cad3f5,prompt:#c6a0f6,hl+:#ed8796,border:#8aadf4",
}, ",")

-- Preview command for the file pickers. "{}" is the selected line, i.e. the
-- file path. Directories are previewed with a listing instead of "bat" (which
-- cannot render them).
local FILE_PREVIEW = table.concat({
  "if [ -d {} ]; then",
  "ls -la --color=always {} 2>/dev/null || ls -la {};",
  "else bat --style=numbers --color=always -- {}; fi",
}, " ")

-- Preview command for the grep pickers. These use a ":" delimiter, so "{1}" is
-- the file and "{2}" the line number, which "bat" highlights and scrolls to.
local GREP_PREVIEW =
  "bat --style=numbers --color=always --highlight-line {2} -- {1}"
local GREP_PREVIEW_WINDOW = "right,60%,border-left,+{2}-/2"

-- Directories / files ignored by the "fd" and "rg" pickers. Keep this in sync
-- with the "fd" find command and the "grepprg" in init.lua.
local IGNORE = { ".git", "node_modules", "dist", ".DS_Store" }

-- "fd --exclude ..." flags built from IGNORE.
local FD_EXCLUDES = (function()
  local parts = {}
  for _, name in ipairs(IGNORE) do
    parts[#parts + 1] = "--exclude " .. name
  end
  return table.concat(parts, " ")
end)()

-- "rg --glob '!...'" flags built from IGNORE. "quote" is the quote character to
-- wrap each glob in: a single quote for a plain command, or a double quote when
-- the command is embedded in a single quoted fzf "--bind".
local function rg_globs(quote)
  local parts = {}
  for _, name in ipairs(IGNORE) do
    parts[#parts + 1] = "--glob " .. quote .. "!" .. name .. quote
  end
  return table.concat(parts, " ")
end

-- Floating window geometry for the picker: centered and covering 80% of the
-- editor.
local function get_window_config()
  local width = vim.o.columns
  local height = vim.o.lines
  local win_height = math.ceil(height * 0.8)
  local win_width = math.ceil(width * 0.8)
  return {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = math.ceil((height - win_height) / 2),
    col = math.ceil((width - win_width) / 2),
    border = "rounded",
  }
end

-- The "PickerNormal" and "PickerBorder" highlight groups are defined in the
-- Catppuccin "custom_highlights" in init.lua.
local function create_fzf_window()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  local win = vim.api.nvim_open_win(buf, true, get_window_config())
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:PickerNormal,NormalFloat:PickerNormal,FloatBorder:PickerBorder",
    { win = win }
  )
  state.buf = buf
  state.win = win
  return buf, win
end

-- Close the picker window, delete its buffer and clear the tracked state.
local function teardown_fzf_window(buf, win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  if state.buf == buf then
    state.buf = nil
  end
  if state.win == win then
    state.win = nil
  end
end

-- Build the "fzf" part of a pipeline with the common flags. The individual
-- pickers only have to provide the source of the candidates and the options
-- that differ (preview command, prompt, ...).
--
-- Supported options:
--   * no_multi:       disable multi selection (used by non file pickers)
--   * expect:         comma separated keys that should be reported back
--   * prompt:         the fzf prompt
--   * delimiter:      field delimiter, needed to use "{1}", "{2}", ... in the
--                     preview command
--   * query:          initial query
--   * preview:        preview command
--   * preview_window: preview window layout
--   * extra:          list of additional raw flags (inserted verbatim)
local function build_command(opts)
  opts = opts or {}
  local parts = {
    "fzf",
    "--ansi",
    "--layout=reverse",
    "--info=right",
    "--pointer=" .. vim.fn.shellescape(">"),
    "--bind=ctrl-d:half-page-down",
    "--bind=ctrl-u:half-page-up",
    FZF_COLORS,
  }
  if not opts.no_multi then
    parts[#parts + 1] = "--multi"
  end
  if opts.expect and opts.expect ~= "" then
    parts[#parts + 1] = "--expect=" .. opts.expect
  end
  if opts.prompt then
    parts[#parts + 1] = "--prompt=" .. vim.fn.shellescape(opts.prompt)
  end
  if opts.delimiter then
    parts[#parts + 1] = "--delimiter=" .. vim.fn.shellescape(opts.delimiter)
  end
  if opts.query then
    parts[#parts + 1] = "--query=" .. vim.fn.shellescape(opts.query)
  end
  if opts.preview then
    parts[#parts + 1] = "--preview=" .. vim.fn.shellescape(opts.preview)
    parts[#parts + 1] = "--preview-window="
      .. (opts.preview_window or "right,60%,border-left")
    parts[#parts + 1] = "--bind=ctrl-p:toggle-preview"
    parts[#parts + 1] = "--bind=ctrl-f:preview-half-page-down"
    parts[#parts + 1] = "--bind=ctrl-b:preview-half-page-up"
  end
  for _, extra in ipairs(opts.extra or {}) do
    parts[#parts + 1] = extra
  end
  return table.concat(parts, " ")
end

-- Run fzf inside a floating terminal window.
--
-- The selection is written to a tempfile and read back on exit, which is far
-- more reliable than scraping the rendered terminal buffer. When "expect" is
-- set, fzf prints the pressed key on the first line, followed by the selected
-- lines.
--
-- Supported options:
--   * fzf:       the built fzf command (see "build_command")
--   * source:    shell command that produces the candidates (optional)
--   * entries:   list of candidate lines produced in Lua (optional)
--   * cwd:       working directory for the spawned job
--   * expect:    comma separated keys (must match the "expect" of "fzf")
--   * on_select: function(key, selections) called with the result
local function run_fzf(opts)
  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end

  local tmpfile = vim.fn.tempname()
  local inputfile

  local pipeline = opts.fzf
  if opts.entries then
    inputfile = vim.fn.tempname()
    vim.fn.writefile(opts.entries, inputfile)
    pipeline = "cat " .. vim.fn.shellescape(inputfile) .. " | " .. opts.fzf
  elseif opts.source and opts.source ~= "" then
    pipeline = opts.source .. " | " .. opts.fzf
  end

  local buf, win = create_fzf_window()

  -- wrap in a brace group so the redirect applies to fzf's stdout, else it
  -- would be an empty temp file.
  local full_cmd = ("{ %s\n} > %s"):format(
    pipeline,
    vim.fn.shellescape(tmpfile)
  )

  local job
  job = vim.fn.jobstart(full_cmd, {
    term = true,
    cwd = opts.cwd,
    on_exit = function(_, code, _)
      vim.schedule(function()
        teardown_fzf_window(buf, win)
        if state.job == job then
          state.job = nil
        end

        local lines = {}
        if vim.fn.filereadable(tmpfile) == 1 then
          lines = vim.fn.readfile(tmpfile)
        end
        pcall(vim.fn.delete, tmpfile)
        if inputfile then
          pcall(vim.fn.delete, inputfile)
        end

        if code ~= 0 then
          return
        end

        local key = ""
        local selections = {}
        if opts.expect and opts.expect ~= "" then
          key = lines[1] or ""
          for i = 2, #lines do
            if lines[i] ~= "" then
              selections[#selections + 1] = lines[i]
            end
          end
        else
          for i = 1, #lines do
            if lines[i] ~= "" then
              selections[#selections + 1] = lines[i]
            end
          end
        end

        if #selections > 0 then
          opts.on_select(key, selections)
        end
      end)
    end,
  })

  if job <= 0 then
    teardown_fzf_window(buf, win)
    pcall(vim.fn.delete, tmpfile)
    if inputfile then
      pcall(vim.fn.delete, inputfile)
    end
    vim.notify("picker: failed to start fzf", vim.log.levels.ERROR)
    return
  end

  state.job = job
  vim.cmd("startinsert")
end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

-- Join a relative path with the given directory. Absolute paths are returned
-- unchanged.
local function join(dir, path)
  if path:sub(1, 1) == "/" then
    return path
  end
  return (dir:gsub("/$", "")) .. "/" .. path
end

-- Open the given files. "key" decides how they are opened: "ctrl-s" in a
-- horizontal split, "ctrl-v" in a vertical split, "ctrl-t" in a new tab,
-- everything else (enter) in the current window. When multiple files are
-- selected all of them are opened.
local function open_files(specs, key)
  for _, spec in ipairs(specs) do
    if key == "ctrl-s" then
      vim.cmd("split " .. vim.fn.fnameescape(spec.path))
    elseif key == "ctrl-v" then
      vim.cmd("vsplit " .. vim.fn.fnameescape(spec.path))
    elseif key == "ctrl-t" then
      vim.cmd("tabedit " .. vim.fn.fnameescape(spec.path))
    else
      vim.cmd.edit(vim.fn.fnameescape(spec.path))
    end
    if spec.lnum then
      pcall(
        vim.api.nvim_win_set_cursor,
        0,
        { spec.lnum, math.max((spec.col or 1) - 1, 0) }
      )
      pcall(vim.cmd.normal, { "zz", bang = true })
    end
  end
end

-- Populate the quickfix list with "items" and open it.
local function to_quickfix(items, title)
  if #items == 0 then
    return
  end
  vim.fn.setqflist({}, " ", { title = title or "picker", items = items })
  vim.cmd("copen")
end

-- Select handler for pickers whose candidates are plain file paths.
local function file_on_select(dir)
  return function(key, selections)
    local specs = {}
    local items = {}
    for _, line in ipairs(selections) do
      local path = join(dir, line)
      specs[#specs + 1] = { path = path }
      items[#items + 1] = { filename = path, lnum = 1, col = 1, text = line }
    end
    if key == "ctrl-q" then
      to_quickfix(items, "Files")
    else
      open_files(specs, key)
    end
  end
end

-- Select handler for pickers whose candidates are "file:line:col:text".
local function grep_on_select(dir)
  return function(key, selections)
    local specs = {}
    local items = {}
    for _, line in ipairs(selections) do
      -- lazy (.-) matches the first file:line:col, so a colon inside the
      -- matched text can't throw off the capture.
      local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
      if file then
        local path = join(dir, file)
        specs[#specs + 1] =
          { path = path, lnum = tonumber(lnum), col = tonumber(col) }
        items[#items + 1] = {
          filename = path,
          lnum = tonumber(lnum),
          col = tonumber(col),
          text = text,
        }
      end
    end
    if key == "ctrl-q" then
      to_quickfix(items, "Search")
    else
      open_files(specs, key)
    end
  end
end

-- Select handler for the git diff hunks picker. Candidates are
-- "file:line:hunk header" (no column).
local function hunk_on_select(dir)
  return function(key, selections)
    local specs = {}
    local items = {}
    for _, line in ipairs(selections) do
      local file, lnum, text = line:match("^(.-):(%d+):(.*)$")
      if file then
        local path = join(dir, file)
        specs[#specs + 1] = { path = path, lnum = tonumber(lnum), col = 1 }
        items[#items + 1] = {
          filename = path,
          lnum = tonumber(lnum),
          col = 1,
          text = text,
        }
      end
    end
    if key == "ctrl-q" then
      to_quickfix(items, "Git Diff")
    else
      open_files(specs, key)
    end
  end
end

-- Return the git repository root or nil when not inside a repository.
local function git_root()
  local out = vim.fn.systemlist("git rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == "" then
    vim.notify("Not a git repository", vim.log.levels.WARN)
    return nil
  end
  return out[1]
end

-- Run "git <args>" in the given root and show the output in a new read-only
-- buffer in a new tab. Used to show commit / stash diffs.
local function open_git_output(root, args, filetype)
  local cmd = { "git", "-C", root }
  vim.list_extend(cmd, args)
  local result = vim.system(cmd, { text = true }):wait()
  local output = result.stdout or ""
  if result.code ~= 0 then
    output = output .. (result.stderr or "")
  end

  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, "\n"))
  vim.bo[buf].filetype = filetype or "git"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

-- Get the word under the cursor or, in visual mode, the current selection.
local function cursor_word()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local ok, region = pcall(
      vim.fn.getregion,
      vim.fn.getpos("v"),
      vim.fn.getpos("."),
      { type = mode }
    )
    -- Leave visual mode synchronously (the "x" flag) so the "<Esc>" is not
    -- queued into the typeahead, where it would later reach the fzf terminal
    -- and abort the picker.
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
      "nx",
      false
    )
    if ok and region and region[1] and region[1] ~= "" then
      return region[1]
    end
  end
  return vim.fn.expand("<cword>")
end

local EXPECT = "ctrl-q,ctrl-s,ctrl-v,ctrl-t"

-- Build the fzf prompt for a picker, styled after the "fzfjira" script: an icon
-- followed by the label.
local function styled(icon, title)
  return {
    prompt = icon .. " " .. title .. ": ",
  }
end

--------------------------------------------------------------------------------
-- FILE PICKERS
--------------------------------------------------------------------------------

-- Find files below "opts.cwd" (default: the current working directory) with
-- "fd" and open the selection.
function M.find_files(opts)
  opts = opts or {}
  local dir = opts.cwd or vim.fn.getcwd()
  local s = styled(opts.icon or "", opts.title or "Files")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    preview = FILE_PREVIEW,
  })
  run_fzf({
    source = "fd --hidden --type f " .. FD_EXCLUDES,
    fzf = fzf,
    cwd = dir,
    expect = EXPECT,
    on_select = file_on_select(dir),
  })
end

-- Buffer helpers used by the buffers picker. They are registered as globals so
-- they can be called from within the fzf terminal via
-- "nvim --server $NVIM --remote-expr v:lua.__picker_buffer_lines()". Globals
-- avoid the quotes that "require('...')" would need, which would clash with the
-- single quoted fzf "--bind". This lets "ctrl-x" delete a buffer and reload the
-- list without leaving the picker.

-- Return the listed buffers as newline separated paths relative to the cwd.
function _G.__picker_buffer_lines()
  local lines = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].buflisted then
      local name = vim.api.nvim_buf_get_name(b)
      if name ~= "" then
        lines[#lines + 1] = vim.fn.fnamemodify(name, ":.")
      end
    end
  end
  return table.concat(lines, "\n")
end

-- Delete the listed buffer whose cwd relative path matches "name".
function _G.__picker_buffer_delete(name)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(b), ":.") == name then
      pcall(vim.api.nvim_buf_delete, b, {})
    end
  end
  return ""
end

-- Pick from the listed buffers. "ctrl-x" deletes the buffer under the cursor
-- and reloads the list without leaving the picker.
function M.buffers()
  local dir = vim.fn.getcwd()
  if _G.__picker_buffer_lines() == "" then
    vim.notify("No listed buffers", vim.log.levels.INFO)
    return
  end
  local s = styled("", "Buffers")
  -- "$NVIM" is the address of the running Neovim, set for terminal jobs. It is
  -- kept literal (double quoted) so it is expanded inside the fzf terminal, not
  -- when the command is built. "--headless" stops the remote client from
  -- emitting terminal setup / capability query sequences into the pipe.
  -- "ctrl-x" deletes the buffer under the cursor and reloads the list.
  local remote = 'nvim --headless --server "$NVIM" --remote-expr'
  local list = remote .. ' "v:lua.__picker_buffer_lines()"'
  local delete = remote .. ' "v:lua.__picker_buffer_delete({})" >/dev/null'
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    preview = FILE_PREVIEW,
    extra = {
      ("--bind 'ctrl-x:execute-silent(%s)+reload(%s)'"):format(delete, list),
    },
  })
  run_fzf({
    source = list,
    fzf = fzf,
    cwd = dir,
    expect = EXPECT,
    on_select = file_on_select(dir),
  })
end

-- Pick from the recently opened files ("v:oldfiles") that still exist below
-- "opts.cwd" (default: the current working directory).
function M.recent(opts)
  opts = opts or {}
  local dir =
    vim.fn.fnamemodify(opts.cwd or vim.fn.getcwd(), ":p"):gsub("/$", "")
  local entries = {}
  local seen = {}
  local current = vim.api.nvim_buf_get_name(0)
  for _, f in ipairs(vim.v.oldfiles) do
    local full = vim.fn.fnamemodify(f, ":p")
    if
      full:sub(1, #dir + 1) == dir .. "/"
      and vim.fn.filereadable(full) == 1
      and full ~= current
      and not seen[full]
    then
      seen[full] = true
      entries[#entries + 1] = full:sub(#dir + 2)
    end
  end
  if #entries == 0 then
    vim.notify("No recent files", vim.log.levels.INFO)
    return
  end
  local s = styled(opts.icon or "", opts.title or "Recent")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    preview = FILE_PREVIEW,
  })
  run_fzf({
    entries = entries,
    fzf = fzf,
    cwd = dir,
    expect = EXPECT,
    on_select = file_on_select(dir),
  })
end

--------------------------------------------------------------------------------
-- GREP PICKERS
--------------------------------------------------------------------------------

-- Live grep below "opts.cwd" (default: the current working directory): ripgrep
-- is re-run on every keystroke and fzf only selects from its output.
function M.grep_project(opts)
  opts = opts or {}
  local dir = opts.cwd or vim.fn.getcwd()
  local s = styled(opts.icon or "", opts.title or "Search")
  -- --disabled turns fzf into a pure selector; ripgrep does the filtering and
  -- is re-run on every keystroke via "change:reload". The "[ -n {q} ]" guard
  -- avoids running "rg ''" when the query is empty and the "{ ...; }" group
  -- keeps a "head" SIGPIPE from clearing the result list. "-- {q}" stops
  -- queries starting with "-" from being parsed as ripgrep flags.
  -- Note: the globs use double quotes because this ripgrep command is embedded
  -- in a single quoted fzf "--bind" below.
  local rg = table.concat({
    "rg --column --line-number --no-heading --color=always --smart-case",
    "--hidden --max-columns=150 --max-columns-preview " .. rg_globs('"'),
  }, " ")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    delimiter = ":",
    preview = GREP_PREVIEW,
    preview_window = GREP_PREVIEW_WINDOW,
    extra = {
      "--disabled",
      "--bind 'start:reload(echo \"Type to search...\")'",
      ("--bind 'change:reload([ -n {q} ] && { %s -- {q} 2>/dev/null | head -n 5000; } || echo)'"):format(
        rg
      ),
    },
  })
  run_fzf({
    source = "true",
    fzf = fzf,
    cwd = dir,
    expect = EXPECT,
    on_select = grep_on_select(dir),
  })
end

-- One-shot grep for a fixed pattern (fuzzy filtered in fzf afterwards).
function M.grep_pattern(pattern, opts)
  opts = opts or {}
  local dir = opts.cwd or vim.fn.getcwd()
  local s = styled(opts.icon or "", opts.title or "Search")
  local flags = opts.fixed_strings and "-F" or ""
  local rg = table.concat({
    "rg --column --line-number --no-heading --color=always --smart-case",
    "--hidden " .. rg_globs("'"),
    flags,
    "-e",
    vim.fn.shellescape(pattern),
    "2>/dev/null",
  }, " ")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    delimiter = ":",
    query = opts.query,
    preview = GREP_PREVIEW,
    preview_window = GREP_PREVIEW_WINDOW,
  })
  run_fzf({
    source = rg,
    fzf = fzf,
    cwd = dir,
    expect = EXPECT,
    on_select = grep_on_select(dir),
  })
end

-- Grep for the word under the cursor or, in visual mode, the current selection.
function M.grep_word(opts)
  opts = opts or {}
  local word = cursor_word()
  if not word or word == "" then
    vim.notify("No word under cursor", vim.log.levels.WARN)
    return
  end
  M.grep_pattern(
    word,
    vim.tbl_extend("force", {
      icon = "",
      title = word,
      fixed_strings = true,
    }, opts)
  )
end

-- Grep for common todo / warning tags (todo, fixme, bug, ...).
function M.grep_todos(opts)
  M.grep_pattern(
    [[(?i)(todo|warn|info|xxx|bug|fixme|fixit|issue):]],
    vim.tbl_extend("force", { icon = "", title = "Todos" }, opts or {})
  )
end

--------------------------------------------------------------------------------
-- GIT PICKERS
--------------------------------------------------------------------------------

-- Pick from the files tracked by git ("git ls-files") in the repository root.
function M.git_files()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Git Files")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    preview = FILE_PREVIEW,
  })
  run_fzf({
    source = "git ls-files",
    fzf = fzf,
    cwd = root,
    expect = EXPECT,
    on_select = file_on_select(root),
  })
end

-- Pick a git branch and check it out.
function M.git_branches()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Branches")
  local fzf = build_command({
    no_multi = true,
    prompt = s.prompt,
    preview = "git log --oneline --color=always --max-count=50 {1}",
  })
  run_fzf({
    source = "git branch --format='%(refname:short)'",
    fzf = fzf,
    cwd = root,
    on_select = function(_, selections)
      local branch = vim.trim(selections[1])
      local result =
        vim.system({ "git", "-C", root, "checkout", branch }):wait()
      if result.code ~= 0 then
        vim.notify(
          result.stderr or ("Failed to checkout " .. branch),
          vim.log.levels.ERROR
        )
      else
        vim.notify("Checked out " .. branch)
        vim.cmd("checktime")
      end
    end,
  })
end

-- git diff: list every hunk of the unstaged working tree changes. Each row is
-- "file:line:hunk header" and pressing enter opens the file at the hunk.
function M.git_diff()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Git Diff")
  -- Parse the unified diff into "file:line:context" rows, one per hunk. The
  -- hunk header "@@ -a,b +c,d @@" reports "c" as the hunk start, which includes
  -- git's leading context lines, so jumping there lands a few lines before the
  -- change. Instead we walk the hunk body and emit the new-file line number of
  -- the first changed ("+" or "-") line. Context and additions advance the
  -- new-file counter; deletions do not.
  local source = [[git diff --no-color | awk '
/^diff --git /{ infile=1; hunk=0; file=""; next }
infile && /^\+\+\+ /{ file=$0; sub(/^\+\+\+ /,"",file); sub(/^b\//,"",file); infile=0; next }
/^@@ /{
  if (file=="" || file=="/dev/null") { hunk=0; next }
  if (match($0,/\+[0-9]+/)) nl=substr($0,RSTART+1,RLENGTH-1);
  ctx=$0; sub(/^@@[^@]*@@ ?/,"",ctx);
  hunk=1; printed=0; next
}
hunk {
  c=substr($0,1,1);
  if (!printed && (c=="+" || c=="-")) { printf "%s:%s:%s\n", file, nl, ctx; printed=1 }
  if (c==" " || c=="+") nl++
}
']]
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    delimiter = ":",
    preview = GREP_PREVIEW,
    preview_window = GREP_PREVIEW_WINDOW,
  })
  run_fzf({
    source = source,
    fzf = fzf,
    cwd = root,
    expect = EXPECT,
    on_select = hunk_on_select(root),
  })
end

-- git status: all changed files (staged, unstaged and untracked).
function M.git_status()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Git Status")
  local fzf = build_command({
    expect = EXPECT,
    prompt = s.prompt,
    preview = table.concat({
      "if git diff HEAD --color=always -- {} | grep -q .;",
      "then git diff HEAD --color=always -- {};",
      "else bat --style=numbers --color=always -- {}; fi",
    }, " "),
  })
  run_fzf({
    -- Strip the "XY " status prefix and, for renames, the "old -> " part so
    -- that only the path remains.
    source = "git -c core.quotepath=false status --porcelain | sed -E 's/^...//; s/.* -> //'",
    fzf = fzf,
    cwd = root,
    expect = EXPECT,
    on_select = file_on_select(root),
  })
end

-- Pick a git stash entry and show its diff in a new tab.
function M.git_stash()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Git Stash")
  local fzf = build_command({
    no_multi = true,
    prompt = s.prompt,
    delimiter = ":",
    preview = "git stash show --patch --color=always {1}",
  })
  run_fzf({
    source = "git stash list",
    fzf = fzf,
    cwd = root,
    on_select = function(_, selections)
      local stash = selections[1]:match("^(stash@{%d+})")
      if stash then
        open_git_output(root, { "stash", "show", "--patch", stash })
      end
    end,
  })
end

local GIT_LOG_FORMAT =
  "--format='%C(yellow)%h%C(reset) %C(cyan)%ad%C(reset) %s %C(green)(%an)%C(reset)'"

-- Select handler for the git log pickers: show the chosen commit in a new tab.
local function git_log_on_select(root)
  return function(_, selections)
    local sha = selections[1]:match("^(%S+)")
    if sha then
      open_git_output(root, { "show", sha })
    end
  end
end

-- Pick a commit from the repository history and show it in a new tab.
function M.git_log()
  local root = git_root()
  if not root then
    return
  end
  local s = styled("", "Git Log")
  local fzf = build_command({
    no_multi = true,
    prompt = s.prompt,
    preview = "git show --color=always {1}",
  })
  run_fzf({
    source = ("git log --color=always --date=short %s"):format(GIT_LOG_FORMAT),
    fzf = fzf,
    cwd = root,
    on_select = git_log_on_select(root),
  })
end

-- git file log: history of the current file.
function M.git_file_log()
  local root = git_root()
  if not root then
    return
  end
  local file = vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file in the current buffer", vim.log.levels.WARN)
    return
  end
  local s = styled("", "Git File Log")
  local fzf = build_command({
    no_multi = true,
    prompt = s.prompt,
    preview = "git show --color=always {1}",
  })
  run_fzf({
    source = ("git log --follow --color=always --date=short %s -- %s"):format(
      GIT_LOG_FORMAT,
      vim.fn.shellescape(file)
    ),
    fzf = fzf,
    cwd = root,
    on_select = git_log_on_select(root),
  })
end

return M
