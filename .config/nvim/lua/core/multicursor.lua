local M = {}

-- Pattern of the active multicursor session. Kept in a module-local instead of
-- the "/" search register so that placing cursors neither highlights every
-- match (which would drown out the cursor markers) nor clobbers the user's own
-- search when they later press "/". add_next reuses it to keep matching the
-- session's pattern across presses.
local last_pattern

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
  last_pattern = pattern
  vim.api.nvim_win_set_cursor(0, { matches[1].lnum, matches[1].byteidx })
  for i = 2, #matches do
    vim.api.nvim_mcursor(0, { matches[i].lnum, matches[i].byteidx })
  end
  vim.api.nvim_feedkeys(vim.keycode("1q="), "n", false)
end

-- Whether a multicursor session is currently active (cursors exist).
local function session_active()
  local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
  return ns ~= nil
    and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { limit = 1 }) > 0
end

-- Return the position { row (1-based), col (0-based) } of the "frontier"
-- cursor: the primary cursor together with every extra cursor, reduced to the
-- furthest one in the given direction (the lowest for delta > 0, the highest
-- for delta < 0, the last in buffer order for a forward search).
local function frontier(compare)
  local best = vim.api.nvim_win_get_cursor(0)
  local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
  if ns then
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
      local p = { m[2] + 1, m[3] }
      if compare(p, best) then
        best = p
      end
    end
  end
  return best
end

-- Add a cursor on the line above / below the column, keeping the current
-- column, and enable follow-mode so subsequent edits/motions replay across all
-- cursors. The primary cursor is deliberately kept in place: Neovim replays a
-- mapping's keys at every cursor when the mapping moves the primary by API
-- while follow-mode is enabled (see Neovim's mc_clock_edge), which would
-- corrupt the cursor set on the next press. Extending the column only by
-- placing extra cursors avoids that, and the primary still participates in the
-- replayed edits.
local function add_line_cursor(delta)
  return function()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local edge = frontier(function(p, best)
      return delta > 0 and p[1] > best[1] or delta < 0 and p[1] < best[1]
    end)
    local target = edge[1] + delta
    if target < 1 or target > vim.fn.line("$") then
      return
    end
    local target_col = math.min(col, math.max(#vim.fn.getline(target) - 1, 0))
    vim.api.nvim_mcursor(0, { target, target_col })
    vim.api.nvim_feedkeys(vim.keycode("1q="), "n", false)
  end
end

-- Create a cursor for the next occurrence of the word under the cursor (or the
-- Visual selection) and enable follow-mode. Repeated presses add a cursor at
-- each further occurrence. As with add_line_cursor, the primary cursor is kept
-- in place (it stays on the first match and still participates in edits) so
-- that follow-mode does not cause the mapping to cascade across cursors.
local function add_next()
  local mode = vim.fn.mode()
  local visual = mode == "v" or mode == "V" or mode == "\22"
  -- While a multicursor session is already active, keep matching the session's
  -- stored pattern instead of recomputing it from the word under the cursor,
  -- so a session started from a Visual selection keeps matching the whole
  -- selection rather than falling back to the leading word.
  local active = session_active()
  local pattern = (not visual and active) and last_pattern
    or search_pattern()
  if visual then
    -- Put the primary cursor on the start of the selection (where the matched
    -- text begins) rather than where the cursor happens to sit after leaving
    -- Visual mode (its end).
    local a, b = vim.fn.getpos("v"), vim.fn.getpos(".")
    local s = (a[2] < b[2] or (a[2] == b[2] and a[3] <= b[3])) and a or b
    vim.api.nvim_feedkeys(vim.keycode("<esc>"), "nx", false)
    vim.api.nvim_win_set_cursor(0, { s[2], s[3] - 1 })
  elseif not active then
    -- On a fresh Normal-mode start, snap the primary to the start of the word
    -- so it lands on the match boundary (matching every occurrence). This is
    -- safe: follow-mode is still off on the first press, so it cannot cascade.
    vim.fn.search(pattern, "bcW")
  end
  last_pattern = pattern
  ---@type { lnum: integer, byteidx: integer }[]
  local matches = vim.fn.matchbufline("%", pattern, 1, "$")
  if #matches > 0 then
    -- Positions already covered by a cursor: the primary and every extra. The
    -- primary counts even though it has no extmark, so wrapping never places a
    -- duplicate cursor on top of it.
    local covered = {}
    local pr = vim.api.nvim_win_get_cursor(0)
    covered[pr[1] .. ":" .. pr[2]] = true
    local ns = vim.api.nvim_get_namespaces()["nvim.multicursor"]
    if ns then
      for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do
        covered[(m[2] + 1) .. ":" .. m[3]] = true
      end
    end
    -- Walk the matches starting after the furthest cursor and wrapping around,
    -- then add the first one that is not already covered. When every match is
    -- covered this is a no-op.
    local edge = frontier(function(p, best)
      return p[1] > best[1] or (p[1] == best[1] and p[2] > best[2])
    end)
    local after, wrapped = {}, {}
    for _, m in ipairs(matches) do
      if m.lnum > edge[1] or (m.lnum == edge[1] and m.byteidx > edge[2]) then
        after[#after + 1] = m
      else
        wrapped[#wrapped + 1] = m
      end
    end
    vim.list_extend(after, wrapped)
    for _, m in ipairs(after) do
      if not covered[m.lnum .. ":" .. m.byteidx] then
        vim.api.nvim_mcursor(0, { m.lnum, m.byteidx })
        break
      end
    end
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
