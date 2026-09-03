local M = {}

-- Multiple cursors are provided by Neovim's built-in multicursor support
-- (see ":help multiple-cursors"), so no plugin is required. The built-in
-- commands already cover most operations:
--
--   Q            Toggle a cursor at the current position.
--   {Visual}Q    Place a cursor on each line of the selection.
--   q=           Toggle follow-mode (motions replay per cursor).
--   1q=          Enable follow-mode.
--   2q=          Disable follow-mode.
--   ]C / [C      Jump to the next / previous cursor.
--   gQ           Restore the previous multicursors.
--   <c-l>        Clear all cursors (and the search highlight).
--
-- The keymaps below reproduce the behaviour of the multicursor.nvim plugin
-- that is not available through a single built-in key:
--
--   <c-k>        Add a cursor on the line above (keeping the current column).
--   <c-j>        Add a cursor on the line below (keeping the current column).
--   <c-n>        Add a cursor for the next occurrence of the word under the
--                cursor (or the Visual selection).
--   <c-a>        Add a cursor for all occurrences of the word under the cursor
--                (or the Visual selection) in the buffer.
--   <c-h>        Add a cursor for every match of a provided pattern within the
--                Visual selection (or the whole buffer in Normal mode).

-- Build the search pattern for the current context: the word under the cursor
-- in Normal mode or a literal (very-nomagic) match of the Visual selection.
local function search_pattern()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local region =
      vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
    return "\\V" .. vim.fn.escape(table.concat(region, "\n"), "\\")
  end
  return "\\<" .. vim.fn.expand("<cword>") .. "\\>"
end

-- Return the target line range for the current mode: the Visual selection or,
-- in Normal mode, the whole buffer. Leaves Visual mode synchronously.
local function range()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local p1, p2 = vim.fn.getpos("v"), vim.fn.getpos(".")
    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "nx", false)
    return math.min(p1[2], p2[2]), math.max(p1[2], p2[2])
  end
  return 1, vim.fn.line("$")
end

-- Place a cursor at every match of the pattern within the line range, move the
-- real cursor onto the first match (so it doesn't linger on a non-matching
-- position) and enable follow-mode.
local function match_cursors(pattern, sline, eline)
  ---@type { lnum: integer, byteidx: integer }[]
  local matches = vim.fn.matchbufline("%", pattern, sline, eline)
  if #matches == 0 then
    return
  end
  vim.fn.setreg("/", pattern)
  vim.opt.hlsearch = true
  vim.api.nvim_win_set_cursor(0, { matches[1].lnum, matches[1].byteidx })
  for i = 2, #matches do
    vim.api.nvim_mcursor(0, { matches[i].lnum, matches[i].byteidx })
  end
  vim.api.nvim_feedkeys(vim.keycode("1q="), "n", false)
end

-- Add a cursor on the line above / below (keeping the current column) and
-- enable follow-mode, so subsequent motions replay across all cursors. The
-- column is built with the API instead of a "j"/"k" motion, otherwise
-- follow-mode would replay that motion and move the whole column instead of
-- extending it.
local function add_line_cursor(delta)
  return function()
    local pos = vim.api.nvim_win_get_cursor(0)
    local row, col = pos[1], pos[2]
    local target = row + delta
    if target < 1 or target > vim.fn.line("$") then
      return
    end
    vim.api.nvim_mcursor(0, { row, col })
    local target_col = math.min(col, math.max(#vim.fn.getline(target) - 1, 0))
    vim.api.nvim_win_set_cursor(0, { target, target_col })
    vim.api.nvim_feedkeys(vim.keycode("1q="), "n", false)
  end
end

-- Create a cursor for the word under the cursor (or the Visual selection),
-- jump to its next occurrence (via the API so follow-mode doesn't replay the
-- jump) and enable follow-mode. Repeated presses add cursors incrementally.
local function add_next()
  local mode = vim.fn.mode()
  local visual = mode == "v" or mode == "V" or mode == "\22"
  -- While a multicursor session is already active, keep matching the session's
  -- search pattern instead of recomputing it from the word under the cursor,
  -- so a session started from a Visual selection keeps matching the whole
  -- selection rather than falling back to the leading word.
  local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
  local active = ns ~= nil
    and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { limit = 1 }) > 0
  local pattern = (not visual and active) and vim.fn.getreg("/")
    or search_pattern()
  if visual then
    -- Place the first cursor at the start of the selection (where the matched
    -- text begins) rather than where the cursor happens to sit after leaving
    -- Visual mode (its end).
    local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
    local s = (a[2] < b[2] or (a[2] == b[2] and a[3] <= b[3])) and a or b
    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "nx", false)
    vim.api.nvim_win_set_cursor(0, { s[2], s[3] - 1 })
  end
  -- On a fresh Normal-mode start, snap the cursor to the start of the word so
  -- the first cursor lands on the match boundary (matching every subsequent
  -- occurrence) instead of wherever the cursor happened to sit within the word.
  if not visual and not active then
    vim.fn.search(pattern, "bcW")
  end
  vim.fn.setreg("/", pattern)
  vim.opt.hlsearch = true
  local pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_mcursor(0, { pos[1], pos[2] })
  local next_match = vim.fn.searchpos(pattern, "nw")
  if next_match[1] ~= 0 then
    vim.api.nvim_win_set_cursor(0, { next_match[1], next_match[2] - 1 })
  end
  vim.api.nvim_feedkeys(vim.keycode("1q="), "n", false)
end

-- Create a cursor for all occurrences of the word under the cursor (or the
-- Visual selection) in the buffer and enable follow-mode.
local function add_all()
  local pattern = search_pattern()
  if vim.fn.mode() ~= "n" then
    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "nx", false)
  end
  match_cursors(pattern, 1, vim.fn.line("$"))
end

-- Create a cursor for every match of a provided pattern within the Visual
-- selection (or the whole buffer in Normal mode) and enable follow-mode.
local function add_match()
  local sline, eline = range()
  vim.ui.input({ prompt = "Match: " }, function(pattern)
    if not pattern or pattern == "" then
      return
    end
    match_cursors(pattern, sline, eline)
  end)
end

function M.setup()
  vim.keymap.set("n", "<c-k>", add_line_cursor(-1))
  vim.keymap.set("n", "<c-j>", add_line_cursor(1))
  vim.keymap.set({ "n", "x" }, "<c-n>", add_next)
  vim.keymap.set({ "n", "x" }, "<c-a>", add_all)
  vim.keymap.set({ "n", "x" }, "<c-h>", add_match)
end

return M
