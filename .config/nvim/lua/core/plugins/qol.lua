local icons = require("utils").icons

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    keys = {
      {
        "<leader>p",
        function()
          require("command-palette").show_commands()
        end,
        desc = "Command Palette",
      },
      {
        "<leader>e",
        function()
          Snacks.picker.explorer()
        end,
        desc = "Files",
      },
      {
        "<leader>ff",
        function()
          Snacks.picker.files()
        end,
        desc = "Files",
      },
      {
        "<leader>fs",
        function()
          Snacks.picker.grep()
        end,
        desc = "Search",
      },
      {
        "<leader>fb",
        function()
          Snacks.picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>f/",
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = "Search Buffers",
      },

      {
        "<leader>fr",
        function()
          Snacks.picker.recent({ filter = { cwd = true } })
        end,
        desc = "Recent",
      },
      {
        "<leader>fR",
        function()
          Snacks.picker.resume()
        end,
        desc = "Resume",
      },
      {
        "<leader>fu",
        function()
          Snacks.picker.undo()
        end,
        desc = "Undo",
      },
      {
        "<leader>fk",
        function()
          Snacks.picker.keymaps()
        end,
        desc = "Keymaps",
      },
      {
        "<leader>fl",
        function()
          Snacks.picker.loclist()
        end,
        desc = "Location List",
      },
      {
        "<leader>fm",
        function()
          Snacks.picker.marks()
        end,
        desc = "Marks",
      },
      {
        "<leader>fq",
        function()
          Snacks.picker.qflist()
        end,
        desc = "Quickfix List",
      },
      {
        "<leader>fd",
        function()
          Snacks.picker.diagnostics_buffer()
        end,
        desc = "Buffer Diagnostics",
      },
      {
        "<leader>fD",
        function()
          Snacks.picker.diagnostics()
        end,
        desc = "Workspace Diagnostics",
      },
      {
        "<leader>fgf",
        function()
          Snacks.picker.git_files()
        end,
        desc = "Git Files",
      },
      {
        "<leader>fgb",
        function()
          Snacks.picker.git_branches()
        end,
        desc = "Git Branches",
      },
      {
        "<leader>fgl",
        function()
          Snacks.picker.git_log_file()
        end,
        desc = "Git Log (Buffer)",
      },
      {
        "<leader>fgL",
        function()
          Snacks.picker.git_log()
        end,
        desc = "Git Log (Workspace)",
      },
      {
        "<leader>fgs",
        function()
          Snacks.picker.git_status()
        end,
        desc = "Git Status",
      },
      {
        "<leader>fgS",
        function()
          Snacks.picker.git_stash()
        end,
        desc = "Git Stash",
      },
      {
        "<leader>fls",
        function()
          Snacks.picker.lsp_symbols()
        end,
        desc = "Buffer Symbols",
      },
      {
        "<leader>flS",
        function()
          Snacks.picker.lsp_workspace_symbols()
        end,
        desc = "Workspace Symbols",
      },
      {
        "<leader>flr",
        function()
          Snacks.picker.lsp_references()
        end,
        desc = "References",
      },
      {
        "<leader>fld",
        function()
          Snacks.picker.lsp_definitions()
        end,
        desc = "Definitions",
      },
      {
        "<leader>flD",
        function()
          Snacks.picker.lsp_declarations()
        end,
        desc = "Declarations",
      },
      {
        "<leader>fly",
        function()
          Snacks.picker.lsp_type_definitions()
        end,
        desc = "Type Definitions",
      },
      {
        "<leader>fli",
        function()
          Snacks.picker.lsp_implementations()
        end,
        desc = "Implementations",
      },
    },
    opts = {
      bigfile = {
        enabled = true,
        notify = false,
        size = 1 * 1024 * 1024,
      },
      dashboard = {
        enabled = true,
        autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = "<leader>ff" },
            {
              icon = " ",
              key = "n",
              desc = "New File",
              action = function()
                Snacks.input({
                  prompt = "File Name",
                  default = "untitled",
                }, function(value)
                  vim.cmd("e " .. value .. " | startinsert")
                end)
              end,
            },
            { icon = " ", key = "s", desc = "Find Text", action = "<leader>fs" },
            { icon = " ", key = "r", desc = "Recent Files", action = "<leader>fr" },
            { icon = " ", key = "g", desc = "Git Status", action = "<leader>fgs" },
            { icon = "󰙅 ", key = "e", desc = "Explorer", action = "<leader>e" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
          header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
        },
        sections = {
          { section = "header" },
          {
            icon = " ",
            title = "Keymaps",
            section = "keys",
            enabled = function()
              return vim.o.lines >= 25
            end,
            indent = 2,
            padding = 1,
          },
          {
            icon = " ",
            title = "Recent Files",
            section = "recent_files",
            enabled = function()
              return vim.o.lines >= 35
            end,
            indent = 2,
            padding = 1,
            cwd = true,
          },
          {
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function()
              return Snacks.git.get_root() ~= nil and vim.o.lines >= 45
            end,
            cmd = "git --no-pager diff --stat -B -M -C",
            indent = 2,
            padding = 1,
            height = 10,
            ttl = 60,
          },
          { section = "startup" },
        },
      },
      dim = {
        enabled = true,
        animate = {
          enabled = false,
        },
      },
      gitbrowse = {
        enabled = true,
      },
      indent = {
        enabled = true,
        animate = {
          enabled = false,
        },
      },
      input = {
        enabled = true,
      },
      picker = {
        enabled = true,
        ui_select = true,
        icons = {
          git = {
            enabled = true,
            commit = icons.git.commit,
            staged = icons.git.staged,
            added = icons.git.added,
            deleted = icons.git.deleted,
            ignored = icons.git.ignored,
            modified = icons.git.modified,
            renamed = icons.git.renamed,
            unmerged = icons.git.unmerged,
            untracked = icons.git.untracked,
          },
          diagnostics = icons.diagnostics,
          kinds = icons.kinds,
        },
        win = {
          list = {
            wo = {
              relativenumber = true,
            },
          },
        },
        sources = {
          explorer = {
            auto_close = true,
            hidden = true,
            layout = {
              preset = "default",
              preview = false,
            },
            actions = {
              copy_file_path = {
                action = function(_, item)
                  if not item then
                    return
                  end

                  local vals = {
                    ["BASENAME"] = vim.fn.fnamemodify(item.file, ":t:r"),
                    ["EXTENSION"] = vim.fn.fnamemodify(item.file, ":t:e"),
                    ["FILENAME"] = vim.fn.fnamemodify(item.file, ":t"),
                    ["PATH"] = item.file,
                    ["PATH (CWD)"] = vim.fn.fnamemodify(item.file, ":."),
                    ["PATH (HOME)"] = vim.fn.fnamemodify(item.file, ":~"),
                    ["URI"] = vim.uri_from_fname(item.file),
                  }

                  local options = vim.tbl_filter(function(val)
                    return vals[val] ~= ""
                  end, vim.tbl_keys(vals))
                  if vim.tbl_isempty(options) then
                    vim.notify("No values to copy", vim.log.levels.WARN)
                    return
                  end
                  table.sort(options)
                  vim.ui.select(options, {
                    prompt = "Choose to copy to clipboard:",
                    format_item = function(list_item)
                      return ("%s: %s"):format(list_item, vals[list_item])
                    end,
                  }, function(choice)
                    local result = vals[choice]
                    if result then
                      vim.fn.setreg("+", result)
                      Snacks.notify.info("Yanked `" .. result .. "`")
                    end
                  end)
                end,
              },
              search_in_directory = {
                action = function(_, item)
                  if not item then
                    return
                  end
                  local dir = vim.fn.fnamemodify(item.file, ":p:h")
                  Snacks.picker.grep({
                    cwd = dir,
                    cmd = "rg",
                    args = {
                      "-g",
                      "!.git",
                      "-g",
                      "!node_modules",
                      "-g",
                      "!dist",
                      "-g",
                      "!build",
                      "-g",
                      "!coverage",
                      "-g",
                      "!.DS_Store",
                      "-g",
                      "!.docusaurus",
                      "-g",
                      "!.dart_tool",
                    },
                    show_empty = true,
                    hidden = true,
                    ignored = true,
                    follow = false,
                    supports_live = true,
                  })
                end,
              },
              search_in_directory_case_sensitive = {
                action = function(_, item)
                  if not item then
                    return
                  end
                  local dir = vim.fn.fnamemodify(item.file, ":p:h")
                  Snacks.picker.grep({
                    cwd = dir,
                    cmd = "rg",
                    args = {
                      "-s",
                      "-g",
                      "!.git",
                      "-g",
                      "!node_modules",
                      "-g",
                      "!dist",
                      "-g",
                      "!build",
                      "-g",
                      "!coverage",
                      "-g",
                      "!.DS_Store",
                      "-g",
                      "!.docusaurus",
                      "-g",
                      "!.dart_tool",
                    },
                    show_empty = true,
                    hidden = true,
                    ignored = true,
                    follow = false,
                    supports_live = true,
                  })
                end,
              },
              diff = {
                action = function(picker)
                  picker:close()
                  local sel = picker:selected()
                  if #sel > 0 and sel then
                    Snacks.notify.info(sel[1].file)
                    -- vim.cmd("tabnew " .. sel[1].file .. " vert diffs " .. sel[2].file)
                    vim.cmd("tabnew " .. sel[1].file)
                    vim.cmd("vert diffs " .. sel[2].file)
                    Snacks.notify.info("Diffing " .. sel[1].file .. " against " .. sel[2].file)
                    return
                  end

                  Snacks.notify.info("Select two entries for the diff")
                end,
              },
            },
            win = {
              list = {
                keys = {
                  ["y"] = "copy_file_path",
                  ["s"] = "search_in_directory",
                  ["S"] = "search_in_directory_case_sensitive",
                  ["D"] = "diff",
                },
              },
            },
          },
          files = {
            cmd = "rg",
            args = {
              "-g",
              "!.git",
              "-g",
              "!node_modules",
              "-g",
              "!dist",
              "-g",
              "!build",
              "-g",
              "!coverage",
              "-g",
              "!.DS_Store",
              "-g",
              "!.docusaurus",
              "-g",
              "!.dart_tool",
            },
            show_empty = true,
            hidden = true,
            ignored = true,
            follow = false,
            supports_live = true,
          },
          grep = {
            cmd = "rg",
            args = { "-g", "!.git", "-g", "!node_modules", "-g", "!dist", "-g", "!.DS_Store", "-g", "!.docusaurus" },
            hidden = true,
            ignored = true,
            follow = false,
            supports_live = true,
          },
          marks = {
            global = true,
            ["local"] = false,
            transform = function(item)
              if item.label and item.label:match("^[A-Z]$") and item then
                return item
              end
              return false
            end,
          },
        },
      },
      quickfile = {
        enabled = true,
      },
    },
  },
}
