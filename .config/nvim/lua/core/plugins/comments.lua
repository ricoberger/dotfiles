return {
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "BufReadPre",
    cmd = { "TodoQuickFix", "TodoLocList" },
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next Todo Comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous Todo Comment",
      },
      {
        "<leader>ft",
        function()
          Snacks.picker.todo_comments()
        end,
        desc = "Find Todo Comments",
      },
    },
    opts = {
      signs = true,
      sign_priority = 8,
      keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
      gui_style = {
        fg = "NONE",
        bg = "BOLD",
      },
      search = {
        command = "rg",
        args = {
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--hidden",
          "--no-ignore",
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
      },
    },
  },
}
