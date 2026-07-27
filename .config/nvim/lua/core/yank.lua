local M = {}

-- Show a "vim.ui.select" dialog to copy a reference to the current buffer to
-- the system clipboard, e.g. to paste it into an AI chat. Works in normal mode
-- (using the cursor line) and visual mode (using the selected range).

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

-- The web URL (e.g. GitHub) for the given line range of the current buffer on
-- the current branch, or "" if the file is not inside a Git repository or has
-- no path on disk. SSH/scp-style remotes are normalised to an https URL.
local function git_url(sline, eline)
  local abs = vim.fn.resolve(vim.fn.expand("%:p"))
  if abs == "" then
    return ""
  end
  local dir = vim.fn.fnamemodify(abs, ":h")

  local function git(args)
    local out =
      vim.fn.system("git -C " .. vim.fn.shellescape(dir) .. " " .. args)
    if vim.v.shell_error ~= 0 then
      return ""
    end
    return vim.trim(out)
  end

  local root = vim.fn.resolve(git("rev-parse --show-toplevel"))
  local remote = git("config --get remote.origin.url")
  if root == "" or remote == "" then
    return ""
  end

  remote = remote:gsub("%.git$", "")
  remote = remote:gsub("^git@([^:]+):", "https://%1/")
  remote = remote:gsub("^ssh://git@", "https://")

  local branch = git("branch --show-current")
  if branch == "" then
    branch = git("rev-parse --short HEAD")
  end
  if branch == "" then
    return ""
  end

  -- Path of the file relative to the repository root.
  local relpath = abs:sub(#root + 2)
  local url = ("%s/blob/%s/%s#L%d"):format(remote, branch, relpath, sline)
  if eline ~= sline then
    url = ("%s-L%d"):format(url, eline)
  end
  return url
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
    { "Filename", vim.fn.expand("%:t") },
    { "Relative Path", abs ~= "" and (rel .. suffix) or "" },
    { "Absolute Path", abs ~= "" and (abs .. suffix) or "" },
    { "Git Url", git_url(sline, eline) },
    { "Diagnostic", diagnostic_line() },
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
