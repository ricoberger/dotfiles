return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      suggestion = { enabled = false },
      panel = { enabled = false },
      filetypes = {
        markdown = true,
        help = true,
      },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    version = "*",
    branch = "main",
    dependencies = {
      "zbirenbaum/copilot.lua",
      "nvim-lua/plenary.nvim",
    },
    cmd = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatClose",
      "CopilotChatToggle",
      "CopilotChatReset",
      "CopilotChatSave",
      "CopilotChatLoad",
      "CopilotChatDebugInfo",
      "CopilotChatExplain",
      "CopilotChatTests",
      "CopilotChatFix",
      "CopilotChatOptimize",
      "CopilotChatDocs",
      "CopilotChatFixDiagnostic",
      "CopilotChatCommit",
      "CopilotChatCommitStaged",
      "CopilotChatReview",
    },
    keys = {
      {
        "<leader>ca",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.snacks").pick(actions.prompt_actions())
        end,
        desc = "Actions",
      },
      { "<leader>co", "<cmd>CopilotChatOpen<cr>", desc = "Open" },
      { "<leader>cc", "<cmd>CopilotChatClose<cr>", desc = "Close" },
      { "<leader>ct", "<cmd>CopilotChatToggle<cr>", desc = "Toggle" },
      { "<leader>cr", "<cmd>CopilotChatReset<cr>", desc = "Reset" },
    },
    opts = {},
  },
}
