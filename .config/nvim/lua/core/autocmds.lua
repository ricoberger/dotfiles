local function augroup(name)
  return vim.api.nvim_create_augroup("lazyvim_" .. name, { clear = true })
end

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Show cursor line only in active window
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

-- Remove file from quickfix list via "dd"
-- See https://stackoverflow.com/a/77181885
function Remove_qf_item()
  local curqfidx = vim.fn.line(".")
  local qfall = vim.fn.getqflist()

  if #qfall == 0 then
    return
  end

  table.remove(qfall, curqfidx)
  vim.fn.setqflist(qfall, "r")

  vim.cmd("copen")

  local new_idx = curqfidx < #qfall and curqfidx or math.max(curqfidx - 1, 1)

  local winid = vim.fn.win_getid()
  vim.api.nvim_win_set_cursor(winid, { new_idx, 0 })
end

vim.cmd("command! RemoveQFItem lua Remove_qf_item()")
vim.api.nvim_command("autocmd FileType qf nnoremap <buffer> dd :RemoveQFItem<cr>")

-- Show linters for the current buffer's file type
vim.api.nvim_create_user_command("LintInfo", function()
  local filetype = vim.bo.filetype
  local linters = require("lint").linters_by_ft[filetype]

  if linters then
    print("Linters for " .. filetype .. ": " .. table.concat(linters, ", "))
  else
    print("No linters configured for filetype: " .. filetype)
  end
end, {})

-- Create sequential global marks
-- https://www.reddit.com/r/neovim/comments/1gb055z/creating_sequential_global_marks_open_to/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
local function load_last_mark()
  local file = io.open(vim.fn.stdpath("data") .. "/last_mark.txt", "r")
  if file then
    local mark = file:read("*l")
    file:close()
    return mark
  end
  return nil
end

local function save_last_mark(mark)
  local file = io.open(vim.fn.stdpath("data") .. "/last_mark.txt", "w")
  file:write(mark)
  file:close()
end

local function NewMark()
  if not vim.g.last_mark then
    vim.g.last_mark = load_last_mark() or "Z"
  end

  if vim.g.last_mark == "Z" then
    vim.g.last_mark = "A"
  else
    vim.g.last_mark = string.char(string.byte(vim.g.last_mark) + 1)
  end

  vim.cmd("mark " .. vim.g.last_mark)

  save_last_mark(vim.g.last_mark)

  vim.notify("Mark set: " .. vim.g.last_mark)
end

vim.api.nvim_create_user_command("NewMark", NewMark, { desc = "Create New Global Mark" })
