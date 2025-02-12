local icons = require("utils").icons

return {
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          {
            "diff",
            symbols = {
              added = icons.git.added,
              modified = icons.git.modified,
              removed = icons.git.deleted,
            },
          },
          {
            "diagnostics",
            symbols = {
              error = icons.diagnostics.Error,
              warn = icons.diagnostics.Warn,
              info = icons.diagnostics.Info,
              hint = icons.diagnostics.Hint,
            },
          },
        },
        lualine_c = {
          {
            "tabs",
            -- Disable separators, because of https://github.com/nvim-lualine/lualine.nvim/issues/1322
            component_separators = { left = "" },
            cond = function()
              return #vim.fn.gettabinfo() > 1
            end,
          },
          {
            "buffers",
            -- Disable separators, because of https://github.com/nvim-lualine/lualine.nvim/issues/1322
            component_separators = { left = "" },
            symbols = {
              modified = " ● ",
              alternate_file = "",
              directory = "",
            },
          },
        },
        lualine_x = {
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
}
