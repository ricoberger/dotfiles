local icons = require("utils").icons

return {
  {
    "saghen/blink.cmp",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "fang2hou/blink-copilot",
    },
    version = "1.*",
    event = "VeryLazy",
    opts = {
      keymap = {
        preset = "enter",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "copilot" },
        providers = {
          copilot = {
            name = "copilot",
            module = "blink-copilot",
            score_offset = 100,
            async = true,
            opts = {
              max_completions = 3,
              max_attempts = 4,
            },
          },
        },
      },
      appearance = {
        kind_icons = icons.kinds,
      },
      enabled = function()
        return not vim.tbl_contains({
          "snacks_dashboard",
          "snacks_input",
          "snacks_picker_input",
          "snacks_picker_list",
          "snacks_picker_preview",
          "snacks_layout_box",
          "snacks_terminal",
          "snacks_notif",
        }, vim.bo.filetype)
      end,
      completion = {
        menu = {
          auto_show = function(ctx)
            return ctx.mode ~= "cmdline"
              or not (
                vim.tbl_contains({ "b", "q", "w" }, vim.fn.getcmdline():sub(1, 1))
                or vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
              )
          end,
        },
        accept = {
          auto_brackets = {
            enabled = false,
          },
        },
        list = {
          selection = {
            preselect = true,
            auto_insert = false,
          },
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 500,
        },
        ghost_text = {
          enabled = false,
        },
      },
      signature = {
        enabled = true,
      },
    },
    opts_extend = { "sources.default" },
  },
}
