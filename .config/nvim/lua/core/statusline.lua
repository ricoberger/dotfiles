local M = {}

local SEP_L = ""
local SEP_R = ""
local COMP_L = ""
local COMP_R = ""

local DIFF = { added = "✚", modified = "○", removed = "✖" }
local DIAG = { error = "", warn = "", info = "", hint = "" }
local FILE = { modified = "○", readonly = "󱈸", unnamed = "" }
local FILEFORMAT = { unix = "", dos = "", mac = "" }
local BRANCH_ICON = ""

local MODES = {
  ["n"] = { "NORMAL", "blue" },
  ["no"] = { "O-PENDING", "blue" },
  ["nov"] = { "O-PENDING", "blue" },
  ["noV"] = { "O-PENDING", "blue" },
  ["no\22"] = { "O-PENDING", "blue" },
  ["niI"] = { "NORMAL", "blue" },
  ["niR"] = { "NORMAL", "blue" },
  ["niV"] = { "NORMAL", "blue" },
  ["nt"] = { "NORMAL", "blue" },
  ["ntT"] = { "NORMAL", "blue" },
  ["v"] = { "VISUAL", "mauve" },
  ["vs"] = { "VISUAL", "mauve" },
  ["V"] = { "V-LINE", "mauve" },
  ["Vs"] = { "V-LINE", "mauve" },
  ["\22"] = { "V-BLOCK", "mauve" },
  ["\22s"] = { "V-BLOCK", "mauve" },
  ["s"] = { "SELECT", "mauve" },
  ["S"] = { "S-LINE", "mauve" },
  ["\19"] = { "S-BLOCK", "mauve" },
  ["i"] = { "INSERT", "green" },
  ["ic"] = { "INSERT", "green" },
  ["ix"] = { "INSERT", "green" },
  ["R"] = { "REPLACE", "red" },
  ["Rc"] = { "REPLACE", "red" },
  ["Rx"] = { "REPLACE", "red" },
  ["Rv"] = { "V-REPLACE", "red" },
  ["Rvc"] = { "V-REPLACE", "red" },
  ["Rvx"] = { "V-REPLACE", "red" },
  ["c"] = { "COMMAND", "peach" },
  ["cv"] = { "EX", "peach" },
  ["ce"] = { "EX", "peach" },
  ["r"] = { "REPLACE", "red" },
  ["rm"] = { "MORE", "peach" },
  ["r?"] = { "CONFIRM", "peach" },
  ["!"] = { "SHELL", "peach" },
  ["t"] = { "TERMINAL", "green" },
}

--- @return string label
--- @return string color_key
local function get_mode()
  local code = vim.api.nvim_get_mode().mode
  local m = MODES[code] or MODES[code:sub(1, 1)] or { code:upper(), "blue" }
  return m[1], m[2]
end

--------------------------------------------------------------------------------
-- Components
--------------------------------------------------------------------------------

--- @return string
local function git_branch()
  local dict = vim.b.gitsigns_status_dict
  if not dict or not dict.head or dict.head == "" then
    return ""
  end
  return BRANCH_ICON .. " " .. dict.head
end

--- @return string
local function git_diff()
  local dict = vim.b.gitsigns_status_dict
  if not dict then
    return ""
  end

  local segs = {}
  if (dict.added or 0) > 0 then
    segs[#segs + 1] = "%#StatuslineDiffAdd#" .. DIFF.added .. " " .. dict.added
  end
  if (dict.changed or 0) > 0 then
    segs[#segs + 1] = "%#StatuslineDiffChange#"
      .. DIFF.modified
      .. " "
      .. dict.changed
  end
  if (dict.removed or 0) > 0 then
    segs[#segs + 1] = "%#StatuslineDiffDelete#"
      .. DIFF.removed
      .. " "
      .. dict.removed
  end
  return table.concat(segs, " ")
end

--- @return string
local function diagnostics()
  local counts = vim.diagnostic.count(0)
  local severity = vim.diagnostic.severity

  local order = {
    { severity.ERROR, "StatuslineDiagError", DIAG.error },
    { severity.WARN, "StatuslineDiagWarn", DIAG.warn },
    { severity.INFO, "StatuslineDiagInfo", DIAG.info },
    { severity.HINT, "StatuslineDiagHint", DIAG.hint },
  }

  local segs = {}
  for _, o in ipairs(order) do
    local n = counts[o[1]]
    if n and n > 0 then
      segs[#segs + 1] = "%#" .. o[2] .. "#" .. o[3] .. " " .. n
    end
  end
  return table.concat(segs, " ")
end

--- Section b: branch, diff and diagnostics joined with component separators.
--- Returns nil when there is nothing to show so the caller can collapse the
--- section entirely.
--- @param key string
--- @return string?
local function section_b(key)
  local b_hl = "%#StatuslineB_" .. key .. "#"

  local comps = {}
  local branch = git_branch()
  if branch ~= "" then
    comps[#comps + 1] = b_hl .. branch
  end
  local diff = git_diff()
  if diff ~= "" then
    comps[#comps + 1] = diff
  end
  local diag = diagnostics()
  if diag ~= "" then
    comps[#comps + 1] = diag
  end

  if #comps == 0 then
    return nil
  end

  local sep = " %#StatuslineCompSepB#" .. COMP_L .. " "
  return " " .. table.concat(comps, sep) .. " "
end

--- @return string
local function tabs()
  return vim.fn.tabpagenr() .. "/" .. vim.fn.tabpagenr("$")
end

--- @return string
local function filename()
  local name = vim.fn.expand("%:t")
  if name == "" then
    name = FILE.unnamed
  else
    -- Escape "%" so it is not treated as a statusline item.
    name = name:gsub("%%", "%%%%")
  end

  if vim.bo.modified then
    name = name .. " " .. FILE.modified
  elseif vim.bo.readonly or not vim.bo.modifiable then
    name = name .. " " .. FILE.readonly
  end
  return name
end

--- Section c: tab indicator and filename.
--- @return string
local function section_c()
  return " "
    .. tabs()
    .. " %#StatuslineCompSepC#"
    .. COMP_L
    .. " %#StatuslineC#"
    .. filename()
    .. " "
end

--- @return string
local function encoding()
  local enc = vim.bo.fileencoding
  if enc == "" then
    enc = vim.o.encoding
  end
  return enc
end

--- @return string
local function fileformat()
  return FILEFORMAT[vim.bo.fileformat] or vim.bo.fileformat
end

--- Section x: encoding, file format and filetype.
--- @return string
local function section_x()
  local comps = { encoding(), fileformat() }
  local ft = vim.bo.filetype
  if ft ~= "" then
    comps[#comps + 1] = ft
  end

  local sep = " %#StatuslineCompSepC#" .. COMP_R .. " %#StatuslineC#"
  return " " .. table.concat(comps, sep) .. " "
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

--- Build the full statusline string. Invoked via the "statusline" option.
--- @return string
function M.render()
  local label, key = get_mode()
  local parts = {}

  local function put(s)
    parts[#parts + 1] = s
  end

  -- a: mode.
  put("%#StatuslineA_" .. key .. "# " .. label .. " ")

  -- b: branch / diff / diagnostics (collapses when empty).
  local b = section_b(key)
  if b then
    put("%#StatuslineSepAB_" .. key .. "#" .. SEP_L)
    put("%#StatuslineB_" .. key .. "#" .. b)
    put("%#StatuslineSepBC#" .. SEP_L)
  else
    put("%#StatuslineSepAC_" .. key .. "#" .. SEP_L)
  end

  -- c: tabs / filename.
  put("%#StatuslineC#" .. section_c())

  -- Middle gap.
  put("%#StatuslineC#%=")

  -- x: encoding / format / filetype.
  put("%#StatuslineC#" .. section_x())

  -- y: progress (percentage through the file). "%%" renders as a literal "%".
  put("%#StatuslineSepXY#" .. SEP_R)
  put("%#StatuslineB_" .. key .. "# %p%% ")

  -- z: location.
  put("%#StatuslineSepYZ_" .. key .. "#" .. SEP_R)
  put("%#StatuslineZ_" .. key .. "# %l:%c ")

  return table.concat(parts)
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

local group = vim.api.nvim_create_augroup("core-statusline", { clear = true })

-- Redraw the statusline immediately on mode changes so the mode section and its
-- colors update without waiting for the next redraw.
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  desc = "Refresh statusline on mode change",
  callback = function()
    vim.cmd("redrawstatus")
  end,
})

vim.o.statusline = "%!v:lua.require('core.statusline').render()"

return M
