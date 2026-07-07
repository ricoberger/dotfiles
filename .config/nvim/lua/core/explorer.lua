local M = {}

-- Extends the built-in "dir" plugin (":help dir") with basic file operations:
-- delete, move, copy, rename and diff. Files are selected with a mark / toggle
-- system: "<Tab>" toggles the file under the cursor (or a visual range), marks
-- persist across directories (a global set of absolute paths) and operations
-- act on the marked set. Move and copy use a "paste" model, i.e. they operate
-- into the current directory.

-- Set of marked files, keyed by absolute (normalized) path.
local marked = {}

local ns = vim.api.nvim_create_namespace("core.explorer.marks")

-- Glyph shown in the sign column for marked files.
local MARK_SIGN = "▎"

-- Decode a directory listing line into an absolute path. Mirrors the private
-- "entry_path" of the dir plugin: a trailing "/" marks directories and "\n" in
-- a name is encoded as a null byte.
local function line_path(buf, lnum)
  local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
  if not line or line == "" then
    return nil
  end
  if line:sub(-1) == "/" then
    line = line:sub(1, -2)
  end
  local name = line:gsub("%z", "\n")
  return vim.fs.normalize(
    vim.fs.abspath(vim.fs.joinpath(vim.api.nvim_buf_get_name(buf), name))
  )
end

-- Re-place the mark signs / highlights for every marked file in "buf".
local function redisplay(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local count = vim.api.nvim_buf_line_count(buf)
  for lnum = 1, count do
    local path = line_path(buf, lnum)
    if path and marked[path] then
      vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
        sign_text = MARK_SIGN,
        sign_hl_group = "ExplorerMark",
        line_hl_group = "ExplorerMarkLine",
      })
    end
  end
end

-- Sorted list of marked paths.
local function marked_list()
  local list = {}
  for path in pairs(marked) do
    list[#list + 1] = path
  end
  table.sort(list)
  return list
end

-- Unmark all files.
local function clear_marks()
  marked = {}
end

-- Reload the current directory listing and re-display the marks.
local function reload()
  require("nvim.dir")._reload()
  redisplay(vim.api.nvim_get_current_buf())
end

-- Clear the marks and reload the current directory listing after an operation.
local function after_op()
  clear_marks()
  reload()
end

-- Toggle the mark of the file on line "lnum" of "buf".
local function toggle(buf, lnum)
  local path = line_path(buf, lnum)
  if not path then
    return
  end
  if marked[path] then
    marked[path] = nil
  else
    marked[path] = true
  end
end

-- Confirm a yes / no question, defaulting to "No".
local function confirm(question)
  return vim.fn.confirm(question, "&Yes\n&No", 2) == 1
end

-- Run "cmd" (a list of arguments) and report failures.
local function run(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  if result.code ~= 0 then
    vim.notify(
      vim.trim(result.stderr or "") ~= "" and result.stderr
        or ("command failed: " .. table.concat(cmd, " ")),
      vim.log.levels.ERROR
    )
    return false
  end
  return true
end

--------------------------------------------------------------------------------
-- OPERATIONS
--------------------------------------------------------------------------------

-- Files the operation should act on: the marked set if any, otherwise the file
-- under the cursor.
local function targets(buf, lnum)
  local list = marked_list()
  if #list > 0 then
    return list
  end
  local path = line_path(buf, lnum)
  return path and { path } or {}
end

-- Delete the target files (recursively), after confirmation.
function M.delete()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local paths = targets(buf, lnum)
  if #paths == 0 then
    return
  end

  local question
  if #paths == 1 then
    question = "Delete " .. vim.fn.fnamemodify(paths[1], ":t") .. "?"
  else
    question = "Delete " .. #paths .. " items?"
  end
  if not confirm(question) then
    return
  end

  for _, path in ipairs(paths) do
    if vim.fn.delete(path, "rf") ~= 0 then
      vim.notify("Failed to delete " .. path, vim.log.levels.ERROR)
    end
  end
  after_op()
end

-- Resolve the destination path for "src" when pasting into "dir", confirming an
-- overwrite when the target already exists. Returns nil to skip.
local function resolve_target(src, dir)
  local target =
    vim.fs.normalize(vim.fs.joinpath(dir, vim.fn.fnamemodify(src, ":t")))
  if target == src then
    return nil, "already"
  end
  if vim.fn.empty(vim.fn.glob(target)) == 0 then
    if not confirm("Overwrite " .. vim.fn.fnamemodify(target, ":t") .. "?") then
      return nil, "skip"
    end
    vim.fn.delete(target, "rf")
  end
  return target
end

-- Move the marked files into the current directory.
function M.move()
  local list = marked_list()
  if #list == 0 then
    vim.notify("No marked files", vim.log.levels.INFO)
    return
  end
  local dir = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  for _, src in ipairs(list) do
    local target, reason = resolve_target(src, dir)
    if target then
      run({ "mv", src, target })
    elseif reason == "already" then
      vim.notify(
        vim.fn.fnamemodify(src, ":t") .. " is already in this directory",
        vim.log.levels.INFO
      )
    end
  end
  after_op()
end

-- Copy the marked files into the current directory.
function M.copy()
  local list = marked_list()
  if #list == 0 then
    vim.notify("No marked files", vim.log.levels.INFO)
    return
  end
  local dir = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  for _, src in ipairs(list) do
    local target, reason = resolve_target(src, dir)
    if target then
      run({ "cp", "-R", src, target })
    elseif reason == "already" then
      vim.notify(
        "Cannot copy " .. vim.fn.fnamemodify(src, ":t") .. " onto itself",
        vim.log.levels.INFO
      )
    end
  end
  after_op()
end

-- Rename the file under the cursor, prompting for the new name.
function M.rename()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local src = line_path(buf, lnum)
  if not src then
    return
  end
  local name = vim.fn.input({
    prompt = "Rename: ",
    default = vim.fn.fnamemodify(src, ":t"),
  })
  if name == "" or name == vim.fn.fnamemodify(src, ":t") then
    return
  end
  local target = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(src), name))
  if vim.fn.empty(vim.fn.glob(target)) == 0 then
    if not confirm("Overwrite " .. name .. "?") then
      return
    end
    vim.fn.delete(target, "rf")
  end
  if run({ "mv", src, target }) then
    after_op()
  end
end

-- Diff exactly two marked files in a new tab.
function M.diff()
  local list = marked_list()
  if #list ~= 2 then
    vim.notify("Diff needs exactly 2 marked files", vim.log.levels.WARN)
    return
  end
  for _, path in ipairs(list) do
    if vim.fn.isdirectory(path) == 1 then
      vim.notify("Cannot diff a directory", vim.log.levels.WARN)
      return
    end
  end
  clear_marks()
  vim.cmd("tabnew " .. vim.fn.fnameescape(list[1]))
  vim.cmd("vertical diffsplit " .. vim.fn.fnameescape(list[2]))
end

-- Create a new file (or directory) in the current directory. A trailing "/"
-- creates a directory; otherwise an empty file is created. The name may contain
-- subdirectories, which are created as needed. Marks are kept (creating an
-- entry does not affect the marked set).
function M.create()
  local dir = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  local name = vim.fn.input({ prompt = "New file / directory: " })
  if name == "" then
    return
  end
  local is_dir = name:sub(-1) == "/"
  local target = vim.fs.normalize(vim.fs.joinpath(dir, name))
  if vim.fn.empty(vim.fn.glob(target)) == 0 then
    vim.notify(name .. " already exists", vim.log.levels.WARN)
    return
  end
  if is_dir then
    if vim.fn.mkdir(target, "p") == 0 then
      vim.notify("Failed to create " .. name, vim.log.levels.ERROR)
      return
    end
  else
    local parent = vim.fs.dirname(target)
    if vim.fn.isdirectory(parent) == 0 then
      vim.fn.mkdir(parent, "p")
    end
    if vim.fn.writefile({}, target) ~= 0 then
      vim.notify("Failed to create " .. name, vim.log.levels.ERROR)
      return
    end
  end
  reload()
end

-- Open the target files with "cmd" ("split", "vsplit" or "tabedit"). Operates
-- on the marked set if any, otherwise the entry under the cursor; the marks are
-- cleared afterwards.
function M.open(cmd)
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local paths = targets(buf, lnum)
  if #paths == 0 then
    return
  end
  clear_marks()
  redisplay(buf)
  for _, path in ipairs(paths) do
    vim.cmd(cmd .. " " .. vim.fn.fnameescape(path))
  end
end

-- Show all marked files in the quickfix list.
function M.list_marks()
  local list = marked_list()
  if #list == 0 then
    vim.notify("No marked files", vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, path in ipairs(list) do
    items[#items + 1] = { filename = path, lnum = 1, col = 1, text = path }
  end
  vim.fn.setqflist({}, " ", { title = "Explorer Marks", items = items })
  vim.cmd("copen")
end

-- Grep the current directory using the fzf picker.
function M.grep()
  local dir = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
  require("core.picker").grep_project({ cwd = dir })
end

--------------------------------------------------------------------------------
-- SETUP
--------------------------------------------------------------------------------

-- Set the buffer-local operation keymaps on a directory buffer "buf".
local function attach(buf)
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true })
  end

  map("n", "<Tab>", function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    toggle(buf, lnum)
    redisplay(buf)
  end)
  map("x", "<Tab>", function()
    local first = vim.fn.line("v")
    local last = vim.fn.line(".")
    if first > last then
      first, last = last, first
    end
    for lnum = first, last do
      toggle(buf, lnum)
    end
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
      "nx",
      false
    )
    redisplay(buf)
  end)
  map("n", "<Esc>", function()
    clear_marks()
    redisplay(buf)
  end)
  map("n", "<C-s>", function()
    M.open("split")
  end)
  map("n", "<C-v>", function()
    M.open("vsplit")
  end)
  map("n", "<C-t>", function()
    M.open("tabedit")
  end)
  map("n", "d", M.delete)
  map("n", "r", M.rename)
  map("n", "m", M.move)
  map("n", "c", M.copy)
  map("n", "n", M.create)
  map("n", "<C-q>", M.list_marks)
  map("n", "s", M.grep)
  map("n", "=", M.diff)
end

-- Register the autocommands that attach the explorer to directory buffers.
function M.setup()
  local group = vim.api.nvim_create_augroup("core.explorer", { clear = true })

  -- Directory buffers get "filetype=directory" on their first open; attach the
  -- operation keymaps and show any existing marks then.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "directory",
    callback = function(ev)
      attach(ev.buf)
      redisplay(ev.buf)
    end,
  })

  -- Re-display marks when re-entering an already opened directory buffer (the
  -- dir plugin reuses buffers and re-renders their contents).
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(ev)
      if vim.b[ev.buf].nvim_dir ~= nil then
        redisplay(ev.buf)
      end
    end,
  })
end

return M
