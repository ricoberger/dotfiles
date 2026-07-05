local M = {}

-- Show a "vim.ui.select" dialog to copy a reference to the current buffer to
-- the system clipboard, e.g. to paste it into an AI chat. Works in normal mode
-- (using the cursor line) and visual mode (using the selected range).

-- Format the quickfix list as "relpath:lnum:col: text" lines.
local function quickfix_lines()
  local items = vim.fn.getqflist()
  local lines = {}
  for _, item in ipairs(items) do
    local name = ""
    if item.bufnr and item.bufnr > 0 then
      name = vim.fn.fnamemodify(vim.fn.bufname(item.bufnr), ":.")
    end
    lines[#lines + 1] = ("%s:%d:%d: %s"):format(
      name,
      item.lnum,
      item.col,
      vim.trim(item.text)
    )
  end
  return table.concat(lines, "\n")
end

-- The diagnostic under the cursor as "relpath:line: message", or "" if there is
-- no diagnostic on the cursor line or the buffer has no file. When several
-- diagnostics are on the line the one covering the cursor column is preferred.
local function diagnostic_line()
  local abs = vim.fn.expand("%:p")
  if abs == "" then
    return ""
  end
  local lnum = vim.fn.line(".") - 1
  local col = vim.fn.col(".") - 1
  local diags = vim.diagnostic.get(0, { lnum = lnum })
  if #diags == 0 then
    return ""
  end
  local chosen = diags[1]
  for _, d in ipairs(diags) do
    if col >= d.col and col <= (d.end_col or d.col) then
      chosen = d
      break
    end
  end
  return ("%s:%d: %s"):format(
    vim.fn.fnamemodify(abs, ":."),
    chosen.lnum + 1,
    vim.trim(chosen.message)
  )
end

-- Show the copy menu and write the chosen reference to the "+" register.
function M.menu()
  -- Capture the range while still in visual mode, then leave it so that
  -- "vim.ui.select" does not run from visual mode.
  local mode = vim.fn.mode()
  local sline, eline
  if mode == "v" or mode == "V" or mode == "\22" then
    sline, eline = vim.fn.line("v"), vim.fn.line(".")
    if sline > eline then
      sline, eline = eline, sline
    end
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
      "nx",
      false
    )
  else
    sline = vim.fn.line(".")
    eline = sline
  end

  local abs = vim.fn.expand("%:p")
  local rel = vim.fn.fnamemodify(abs, ":.")
  local suffix = sline == eline and (":" .. sline)
    or (":" .. sline .. "-" .. eline)

  -- Ordered list of { label, value } pairs. "vim.ui.select" preserves this
  -- order, so entries appear as listed here rather than alphabetically.
  local entries = {
    { "File", vim.fn.expand("%:t") },
    { "File relative", abs ~= "" and (rel .. suffix) or "" },
    { "File absolute", abs ~= "" and (abs .. suffix) or "" },
    {
      "Directory relative",
      abs ~= "" and vim.fn.fnamemodify(abs, ":.:h") or "",
    },
    { "Directory absolute", abs ~= "" and vim.fn.expand("%:p:h") or "" },
    { "Diagnostic", diagnostic_line() },
    { "Quickfix list", quickfix_lines() },
  }

  local options = {}
  local vals = {}
  for _, entry in ipairs(entries) do
    if entry[2] ~= "" then
      options[#options + 1] = entry[1]
      vals[entry[1]] = entry[2]
    end
  end
  if vim.tbl_isempty(options) then
    vim.notify("Nothing to copy", vim.log.levels.INFO)
    return
  end

  vim.ui.select(options, {
    prompt = "Copy to clipboard:",
    format_item = function(key)
      local preview = vals[key]:gsub("%s*\n%s*", " ⏎ ")
      if #preview > 60 then
        preview = preview:sub(1, 57) .. "..."
      end
      return ("%s: %s"):format(key, preview)
    end,
  }, function(choice)
    if not choice then
      return
    end
    vim.fn.setreg("+", vals[choice])
    vim.notify("Copied " .. choice .. " to clipboard", vim.log.levels.INFO)
  end)
end

return M
