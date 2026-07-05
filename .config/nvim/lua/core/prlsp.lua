-- Neovim integration for the "prlsp" language server, which surfaces GitHub PR
-- review threads in-editor as diagnostics and provides commands and code
-- actions to reply to, resolve, and create review comments.
--
-- See: https://github.com/ricoberger/prlsp
--
-- The server command is configured in "lsp/prlsp.lua" and enabled via
-- "vim.lsp.enable" in "init.lua".

local M = {}

local SERVER_NAME = "prlsp"
local DIAGNOSTIC_SOURCE = "github-review"

--- Get all PRLSP diagnostics on the cursor line.
--- @return vim.Diagnostic[]
local function get_diagnostics_at_cursor()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1

  --- @type vim.Diagnostic[]
  local result = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(0, { lnum = lnum })) do
    if diagnostic.source == DIAGNOSTIC_SOURCE then
      result[#result + 1] = diagnostic
    end
  end
  return result
end

--- Resolve a single review-thread diagnostic on the cursor line and pass it to
--- `callback`. When several threads share the line the user is prompted to pick
--- one; when none exist a notification is shown and `callback` is not called.
--- @param callback fun(diagnostic: vim.Diagnostic)
--- @return nil
local function with_diagnostic_at_cursor(callback)
  local diagnostics = get_diagnostics_at_cursor()

  if #diagnostics == 0 then
    vim.notify(
      "PRLSP: No review thread found on this line",
      vim.log.levels.WARN
    )
    return
  end

  if #diagnostics == 1 then
    callback(diagnostics[1])
    return
  end

  vim.ui.select(diagnostics, {
    prompt = "Select review thread:",
    --- @param diagnostic vim.Diagnostic
    format_item = function(diagnostic)
      local data = vim.tbl_get(diagnostic, "user_data", "lsp", "data") or {}
      local comments = data.comments or {}
      local author = comments[1] and comments[1].author or "?"
      local first_line = vim.split(
        diagnostic.message or "",
        "\n",
        { plain = true }
      )[1] or ""
      return string.format("@%s: %s", author, first_line)
    end,
  }, function(choice)
    if choice then
      callback(choice)
    end
  end)
end

--- @param bufnr integer
--- @param cmd string
--- @param args any[]?
--- @return nil
local function lsp_exec_command(bufnr, cmd, args)
  args = args or {}

  -- Prefer a client attached to the given buffer, but fall back to any running
  -- prlsp client so buffer-independent commands (e.g. refresh) still work from
  -- a buffer the server did not attach to.
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = SERVER_NAME })[1]
    or vim.lsp.get_clients({ name = SERVER_NAME })[1]
  if not client then
    vim.notify("PRLSP: No LSP client attached", vim.log.levels.WARN)
    return
  end

  client:request(
    "workspace/executeCommand",
    { command = cmd, arguments = args },
    nil,
    bufnr
  )
end

--- Return a window in the current tabpage displaying bufnr, or nil.
--- @param bufnr integer
--- @return integer? win
local function win_showing(bufnr)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      return win
    end
  end
  return nil
end

--- Find an existing buffer whose full name matches `name`, or nil.
--- @param name string
--- @return integer? bufnr
local function find_named_buffer(name)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_buf_get_name(bufnr) == name
    then
      return bufnr
    end
  end
  return nil
end

--- Focus an existing prlsp buffer, opening it in a vertical split if it is not
--- currently displayed.
--- @param bufnr integer
--- @return integer win
local function focus_buffer(bufnr)
  local win = win_showing(bufnr)
  if win then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd.vsplit()
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, bufnr)
  end
  return win
end

--- @alias SplitCallback fun(text: string)

--- Open a markdown editor in a vertical split. Writing the buffer (":w") submits
--- the text via `callback`; discarding it (":q", closing the window, or leaving
--- the buffer) cancels without posting anything. Re-opening the same target
--- focuses the existing draft instead of creating a duplicate.
--- @param title string
--- @param callback SplitCallback | nil
--- @return integer bufnr
--- @return integer win
local function show_split_editor(title, callback)
  local name = "prlsp://" .. title

  local existing = find_named_buffer(name)
  if existing then
    return existing, focus_buffer(existing)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(bufnr, name)
  vim.bo[bufnr].buftype = "acwrite"
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].bufhidden = "wipe"

  vim.cmd.vsplit()

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)

  local submitted = false

  -- Submit on write.
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local text = vim.trim(table.concat(lines, "\n"))
      if text == "" then
        vim.notify(
          "PRLSP: Nothing to submit (buffer is empty)",
          vim.log.levels.WARN
        )
        return
      end

      submitted = true
      vim.bo[bufnr].modified = false

      -- Defer the request and window close so they run outside the write
      -- command's context.
      vim.schedule(function()
        if callback then
          callback(text)
        end
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end)
    end,
  })

  -- Anything that wipes the buffer without a prior write is a cancel.
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      if not submitted then
        vim.notify("PRLSP: Review comment discarded", vim.log.levels.INFO)
      end
    end,
  })

  return bufnr, win
end

--- Open a read-only markdown buffer in a vertical split. Re-opening the same
--- title refreshes the existing buffer instead of creating a duplicate.
--- @param title string
--- @param content string[]
--- @return integer bufnr
--- @return integer win
local function show_split_viewer(title, content)
  local name = "prlsp://" .. title

  local existing = find_named_buffer(name)
  if existing then
    local win = focus_buffer(existing)
    vim.bo[existing].modifiable = true
    vim.api.nvim_buf_set_lines(existing, 0, -1, false, content)
    vim.bo[existing].modifiable = false
    return existing, win
  end

  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(bufnr, name)
  vim.bo[bufnr].filetype = "markdown"
  vim.bo[bufnr].bufhidden = "wipe"

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
  vim.bo[bufnr].modifiable = false

  vim.cmd.vsplit()

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, bufnr)

  return bufnr, win
end

--- Show the full review thread at the current line in a markdown side buffer.
--- @return nil
function M.show_review_thread()
  local filename = vim.fn.expand("%:.")

  with_diagnostic_at_cursor(function(diagnostic)
    local data = vim.tbl_get(diagnostic, "user_data", "lsp", "data")
    if not data then
      vim.notify("PRLSP: Review thread has no data", vim.log.levels.WARN)
      return
    end

    --- @type string[]
    local lines = {}

    -- Title: file location plus resolution/outdated status.
    local location = filename
    if data.line and data.line > 0 then
      location = string.format("%s:%d", filename, data.line)
    end

    local status
    if data.resolved then
      status = "resolved"
    elseif data.outdated then
      status = "outdated"
    end
    if status then
      table.insert(lines, string.format("# %s (%s)", location, status))
    else
      table.insert(lines, "# " .. location)
    end
    table.insert(lines, "")

    local comments = data.comments or {}
    if vim.tbl_isempty(comments) then
      -- Fallback for older servers that don't send structured comments.
      for _, l in
        ipairs(vim.split(diagnostic.message or "", "\n", { plain = true }))
      do
        table.insert(lines, l)
      end
    else
      for idx, comment in ipairs(comments) do
        table.insert(lines, "## @" .. tostring(comment.author))
        table.insert(lines, "")
        for _, l in
          ipairs(vim.split(comment.body or "", "\n", { plain = true }))
        do
          table.insert(lines, l)
        end
        table.insert(lines, "")
        if idx < #comments then
          table.insert(lines, "---")
          table.insert(lines, "")
        end
      end
    end

    show_split_viewer(location .. "#" .. tostring(data.thread_id), lines)
  end)
end

--- Open a markdown split to reply to a PR review thread on the current line.
--- @return nil
function M.reply_to_review_thread()
  local bufnr = vim.api.nvim_get_current_buf()
  -- Resolve the URI and file name up front, while the code buffer is still the
  -- current buffer: the editor callback runs later when a scratch buffer is
  -- focused.
  local uri = vim.uri_from_bufnr(bufnr)
  local filename = vim.fn.expand("%:.")

  with_diagnostic_at_cursor(function(diagnostic)
    local data = vim.tbl_get(diagnostic, "user_data", "lsp", "data")
    if not data then
      vim.notify("PRLSP: Review thread has no data", vim.log.levels.WARN)
      return
    end

    local comment_id = data.comment_id
    if not comment_id or comment_id == 0 then
      vim.notify(
        "PRLSP: Review thread has no comment to reply to",
        vim.log.levels.WARN
      )
      return
    end

    show_split_editor(filename .. "#" .. comment_id, function(input)
      lsp_exec_command(
        bufnr,
        "prlsp.replyToReviewThread",
        { comment_id, uri, input }
      )
    end)
  end)
end

--- Open a markdown split to create a PR review comment.
--- If `range` is provided, it will be used as the target line range.
--- If `range` is nil and the user is in visual mode, the current visual
--- selection is used. Otherwise the current cursor line is used.
--- @param range [integer, integer]|nil 1-indexed line range {start_line, end_line}
--- @return nil
function M.create_review_comment(range)
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.api.nvim_get_mode().mode

  local start_line
  local end_line

  if not range then
    -- "\22" is CTRL-V (blockwise visual).
    if mode:match("^[vV\22]") then
      -- Read the live selection endpoints rather than the "'<"/"'>" marks,
      -- which are only updated on leaving visual mode.
      start_line = vim.fn.line("v")
      end_line = vim.fn.line(".")
      if start_line > end_line then
        start_line, end_line = end_line, start_line
      end
    else
      local pos = vim.api.nvim_win_get_cursor(0)
      start_line = pos[1]
      end_line = pos[1]
    end
  else
    if not range[1] or not range[2] then
      vim.notify(
        "PRLSP: Invalid range (missing start or end line)",
        vim.log.levels.ERROR
      )
      return
    end
    start_line = range[1]
    end_line = range[2]
  end

  if start_line <= 0 or end_line <= 0 or start_line > end_line then
    vim.notify(
      string.format("PRLSP: Invalid line range (%d-%d)", start_line, end_line),
      vim.log.levels.ERROR
    )
    return
  end

  local uri = vim.uri_from_bufnr(bufnr)
  local filename = vim.fn.expand("%:.")

  if start_line == end_line then
    local line = start_line

    show_split_editor(filename .. "#" .. line, function(input)
      lsp_exec_command(bufnr, "prlsp.createReviewComment", { uri, line, input })
    end)
  else
    show_split_editor(
      filename .. "#" .. start_line .. "-" .. end_line,
      function(input)
        lsp_exec_command(
          bufnr,
          "prlsp.createReviewCommentRange",
          { uri, start_line, end_line, input }
        )
      end
    )
  end
end

--- Refresh PR review threads.
--- @return nil
function M.refresh_review_threads()
  lsp_exec_command(0, "prlsp.refreshReviewThreads")
end

--------------------------------------------------------------------------------
-- USER COMMANDS
--------------------------------------------------------------------------------

vim.api.nvim_create_user_command("PRLSPCreateReviewComment", function(opts)
  M.create_review_comment({ opts.line1, opts.line2 })
end, { range = true })

vim.api.nvim_create_user_command("PRLSPReplyToReviewThread", function()
  M.reply_to_review_thread()
end, {})

vim.api.nvim_create_user_command("PRLSPShowReviewThread", function()
  M.show_review_thread()
end, {})

vim.api.nvim_create_user_command("PRLSPRefreshReviewThreads", function()
  M.refresh_review_threads()
end, {})

return M
