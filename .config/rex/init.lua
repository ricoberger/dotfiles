-- Rex configuration
-- See https://www.superlogical.com/rex/docs/customize/config

--------------------------------------------------------------------------------
-- ACTIONS
--------------------------------------------------------------------------------

local terminal = "com.superlogical.terminal"
local chunk_size = 983040 -- 960 KiB, the maximum for format and blob_read

-- Read the screen and scrollback of a terminal as plain text. Long buffers are
-- returned in chunks, which are read with blob_read until the end is reached.
local function read_scrollback(block_id)
  local res, err = rex.block.call(terminal, "format", {
    block_id = block_id,
    format = "text",
    trim = true,
    unwrap = true,
    max_bytes = chunk_size,
  })
  if not res then
    return nil, err
  end

  local parts = { res.content }
  local offset = #res.content
  local id = res.id -- only set when more output remains

  while id do
    local chunk, cerr = rex.block.call(terminal, "blob_read", {
      block_id = block_id,
      id = id,
      offset = offset,
      max_bytes = chunk_size,
    })
    if not chunk then
      return nil, cerr
    end
    parts[#parts + 1] = chunk.data
    offset = offset + #chunk.data
    if chunk.eof or #chunk.data == 0 then
      break
    end
  end

  return table.concat(parts)
end

-- Write the scrollback of the focused pane to a temporary file and open it in
-- Neovim in a new floating window, similar to Ghostty's "write_screen_file".
-- Neovim is started via an interactive zsh, so that the PATH from ~/.zshrc is
-- available.
rex.action({
  name = "scrollback_open",
  title = "Open Scrollback in Neovim",
  category = "Pane",
  run = function(ctx)
    local text, err = read_scrollback(ctx.block_id)
    if not text then
      rex.log("error", "scrollback_open: " .. tostring(err))
      return
    end

    local path = os.tmpname() .. ".txt"
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()

    local _, lerr = rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = "com.superlogical.terminal.shell",
        options = {
          shell = "none",
          command = { "zsh", "-ic", 'exec nvim + "$1"', "zsh", path },
        },
      }),
    })
    if lerr then
      rex.log("error", "scrollback_open: " .. tostring(lerr))
    end
  end,
})

--------------------------------------------------------------------------------
-- SIDEBAR
--------------------------------------------------------------------------------

-- A sidebar on the right of the current tab with the git status, the commits
-- and the pull request of the focused pane's directory. The panes are rendered
-- by ~/.local/bin/rex-sidebar, which opens larger views (files, diffs, logs,
-- ...) in a floating layer via the "sidebar_float" action.

local shell = "com.superlogical.terminal.shell"
local sidebar_bin = os.getenv("HOME") .. "/.local/bin/rex-sidebar"
local sidebar_prefix = "sidebar:"
local sidebar_columns = 64

-- Command that runs argv in dir via an interactive zsh, so that the PATH from
-- ~/.zshrc is available.
local function zsh_command(dir, argv)
  local cmd = { "zsh", "-ic", 'cd -- "$1"; shift; exec "$@"', "zsh", dir }
  for _, arg in ipairs(argv) do
    cmd[#cmd + 1] = arg
  end
  return cmd
end

-- Directory of a terminal: the one the shell reported (a file:// URL), or the
-- one of the program running in the foreground.
local function block_dir(block_id)
  local res = rex.block.call(terminal, "pwd", { block_id = block_id })
  if res and res.pwd and res.pwd ~= "" then
    local path = res.pwd:gsub("^file://[^/]*", "")
    return (
      path:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
      end)
    )
  end
  local proc = rex.block.call(terminal, "process", { block_id = block_id })
  return proc and proc.foreground and proc.foreground.cwd or os.getenv("HOME")
end

-- Position of a block in a layout, as [x, y, w, h] fractions of the window.
local function block_rect(node, block_id)
  if not node then
    return nil
  end
  if node.block_id == block_id then
    return node.rect
  end
  if node.split then
    return block_rect(node.split.before, block_id)
      or block_rect(node.split.after, block_id)
  end
end

local function sidebar_pane(name, dir)
  return rex.layout.block({
    flavor = shell,
    label = sidebar_prefix .. name,
    options = {
      shell = "none",
      command = zsh_command(dir, { sidebar_bin, name }),
    },
  })
end

-- Open or close the sidebar in the current tab.
rex.action({
  name = "sidebar_toggle",
  title = "Toggle Sidebar",
  category = "Pane",
  -- dir: directory for the sidebar (default: the focused pane's directory)
  args = { dir = "string?" },
  run = function(ctx, args)
    local view, err = rex.session.view({})
    if not view then
      rex.log("error", "sidebar_toggle: " .. tostring(err))
      return
    end

    local window
    for _, w in ipairs(view.windows or {}) do
      if w.window_id == view.active_window_id then
        window = w
      end
    end
    local layer
    for _, l in ipairs(window and window.layers or {}) do
      if l.kind == "tiled" then
        layer = l
      end
    end
    if not layer or not layer.layout then
      return
    end

    -- Close the sidebar when it is open.
    local open = false
    for _, b in ipairs(layer.blocks or {}) do
      if b.label and b.label:sub(1, #sidebar_prefix) == sidebar_prefix then
        open = true
        rex.call("block.close", {
          session_id = ctx.session_id,
          block_id = b.block_id,
        })
      end
    end
    if open then
      return
    end

    -- Split the whole tab, so that the sidebar spans the full height, and
    -- give it about sidebar_columns columns.
    local block_id = ctx.block_id or window.focused_block_id
    local ratio = 0.75
    local size = rex.block.call(terminal, "size", { block_id = block_id })
    local rect = block_rect(layer.layout, block_id)
    if size and size.columns and rect and rect[3] > 0 then
      local total = size.columns / rect[3]
      ratio = math.min(math.max(1 - sidebar_columns / total, 0.5), 0.95)
    end

    local root = layer.layout
    local dir = args.dir or block_dir(block_id)
    local split, serr = rex.session.new_split({
      anchor_id = root.split and root.split.split_id or root.block_id,
      direction = "horizontal",
      side = "after",
      ratio = ratio,
      focus = false,
      layout = rex.layout.vertical(
        1 / 3,
        sidebar_pane("git-status", dir),
        rex.layout.vertical(
          0.5,
          sidebar_pane("git-commits", dir),
          sidebar_pane("pr", dir)
        )
      ),
    })
    if serr then
      rex.log("error", "sidebar_toggle: " .. tostring(serr))
      return
    end

    -- Autobalance splits (Rex setting) evens out the panes after the split is
    -- created, so set the width of the sidebar again once that happened.
    if split and split.block_ids and split.block_ids[1] then
      rex.exec({ "sleep", "0.3" })
      rex.session.resize_pane({
        direction = "horizontal",
        before_block_id = block_id,
        after_block_id = split.block_ids[1],
        ratio = ratio,
      })
    end
  end,
})

-- Run a command in a floating layer, e.g.
--   rex do sidebar_float --args '{"command": ["nvim", "file"], "cwd": "/tmp"}'
rex.action({
  name = "sidebar_float",
  title = "Run Command in Floating Layer",
  category = "Pane",
  args = { command = "array", cwd = "string?" },
  run = function(_, args)
    local layer, err = rex.session.new_layer({
      bounds = { 0.1, 0.1, 0.8, 0.8 },
      focus = true,
      layout = rex.layout.block({
        flavor = shell,
        options = {
          shell = "none",
          command = zsh_command(args.cwd or os.getenv("HOME"), args.command),
        },
      }),
    })
    if err then
      rex.log("error", "sidebar_float: " .. tostring(err))
      return
    end
    return { block_id = layer.block_ids and layer.block_ids[1] }
  end,
})

--------------------------------------------------------------------------------
-- GO TO ANYTHING
--------------------------------------------------------------------------------

-- Minimize all floating panes of the current tab, then open "Go to Anything",
-- so the same key hides the floating panes (e.g. subagent workers) and opens
-- one of them.
rex.action({
  name = "floating_go_to",
  title = "Minimize Floating Panes and Go to Anything",
  category = "Pane",
  run = function(ctx, args)
    local view, err = rex.session.view({})
    if not view then
      rex.log("error", "floating_go_to: " .. tostring(err))
    end
    for _, w in ipairs(view and view.windows or {}) do
      if w.window_id == view.active_window_id then
        for _, l in ipairs(w.layers or {}) do
          if l.kind == "floating" and l.state ~= "minimized" then
            rex.session.set_layer_state({
              layer_id = l.layer_id,
              state = "minimized",
            })
          end
        end
      end
    end
    rex.client.queue("pane.go_to")
  end,
})

--------------------------------------------------------------------------------
-- DEFAULT SHORTCUTS
--------------------------------------------------------------------------------

-- Rex has no option to clear all default shortcuts, so we unbind every default
-- key listed in https://www.superlogical.com/rex/docs/reference/mac-actions.
-- Run "rex keymap" after a Rex update to check for new defaults.
local defaults = {
  "alt+cmd+down",
  "alt+cmd+enter",
  "alt+cmd+left",
  "alt+cmd+m",
  "alt+cmd+right",
  "alt+cmd+up",
  "alt+cmd+w",
  "alt+left",
  "alt+right",
  "alt+shift+cmd+down",
  "alt+shift+cmd+enter",
  "alt+shift+cmd+left",
  "alt+shift+cmd+right",
  "alt+shift+cmd+u",
  "alt+shift+cmd+up",
  "cmd+-",
  "cmd+,",
  "cmd+.",
  "cmd+/",
  "cmd+=",
  "cmd+[",
  "cmd+]",
  "cmd+[Digit0]",
  "cmd+[Digit1]",
  "cmd+[Digit2]",
  "cmd+[Digit3]",
  "cmd+[Digit4]",
  "cmd+[Digit5]",
  "cmd+[Digit6]",
  "cmd+[Digit7]",
  "cmd+[Digit8]",
  "cmd+[Digit9]",
  "cmd+backspace",
  "cmd+d",
  "cmd+down",
  "cmd+enter",
  "cmd+f",
  "cmd+g",
  "cmd+k",
  "cmd+left",
  "cmd+n",
  "cmd+r",
  "cmd+right",
  "cmd+t",
  "cmd+up",
  "cmd+w",
  "ctrl+cmd+f",
  "ctrl+cmd+i",
  "ctrl+shift+pagedown",
  "ctrl+shift+pageup",
  "ctrl+shift+tab",
  "ctrl+tab",
  "shift+cmd+,",
  "shift+cmd+.",
  "shift+cmd+=",
  "shift+cmd+[",
  "shift+cmd+]",
  "shift+cmd+d",
  "shift+cmd+down",
  "shift+cmd+enter",
  "shift+cmd+g",
  "shift+cmd+left",
  "shift+cmd+n",
  "shift+cmd+p",
  "shift+cmd+right",
  "shift+cmd+s",
  "shift+cmd+u",
  "shift+cmd+up",
  "shift+cmd+w",
}

for _, key in ipairs(defaults) do
  rex.unbind(key)
end

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

-- Mirrors the keybindings from the Ghostty configuration
-- (.config/ghostty/config).

-- Windows
rex.bind("cmd+n", "client.window.new")
rex.bind("cmd+w", "client.close")
rex.bind("shift+cmd+w", "client.window.close")
rex.bind("ctrl+cmd+f", "client.window.fullscreen.toggle")

-- Sessions
rex.bind("cmd+s>n", "session.new")
rex.bind("cmd+s>r", "session.rename")
rex.bind("cmd+s>s", "session.switch")
rex.bind("cmd+s>c", "session.close")
rex.bind("cmd+s>f", "session.refresh")

-- Tabs
rex.bind("cmd+t", "client.tab.new")
rex.bind("alt+cmd+right", "client.tab.next")
rex.bind("alt+cmd+left", "client.tab.previous")

for i = 1, 9 do
  rex.bind("cmd+[Digit" .. i .. "]", "client.tab.goto", { index = i })
end

-- Splits
rex.bind("cmd+d", "pane.split.right")
rex.bind("shift+cmd+d", "pane.split.down")
rex.bind("shift+cmd+enter", "pane.zoom")

rex.bind("ctrl+cmd+left", "pane.focus.left")
rex.bind("ctrl+cmd+right", "pane.focus.right")
rex.bind("ctrl+cmd+up", "pane.focus.up")
rex.bind("ctrl+cmd+down", "pane.focus.down")

rex.bind("shift+cmd+left", "pane.resize", { direction = "left" })
rex.bind("shift+cmd+right", "pane.resize", { direction = "right" })
rex.bind("shift+cmd+up", "pane.resize", { direction = "up" })
rex.bind("shift+cmd+down", "pane.resize", { direction = "down" })

-- Font size
rex.bind("shift+cmd+=", "client.font.increase")
rex.bind("cmd+=", "client.font.increase")
rex.bind("cmd+-", "client.font.decrease")
rex.bind("cmd+0", "client.font.reset")

-- Misc
rex.bind("cmd+p", "client.palette.toggle")
rex.bind("cmd+g", "floating_go_to")
rex.bind("cmd+a", "client.sidebar.activity.toggle")
rex.bind("cmd+b", "sidebar_toggle")
rex.bind("cmd+f", "scrollback_open")
rex.bind("cmd+,", "client.settings")
