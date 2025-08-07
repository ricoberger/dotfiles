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
      "CopilotChatStop",
      "CopilotChatReset",
      "CopilotChatSave",
      "CopilotChatLoad",
      "CopilotChatPrompts",
      "CopilotChatModels",
    },
    keys = {
      { "<leader>co", "<cmd>CopilotChatOpen<cr>", desc = "Open" },
      { "<leader>cc", "<cmd>CopilotChatClose<cr>", desc = "Close" },
      { "<leader>ct", "<cmd>CopilotChatToggle<cr>", desc = "Toggle" },
      { "<leader>cs", "<cmd>CopilotChatStop<cr>", desc = "Stop" },
      { "<leader>cr", "<cmd>CopilotChatReset<cr>", desc = "Reset" },
    },
    config = function()
      require("CopilotChat").setup({
        model = "claude-3.7-sonnet",
        agent = "copilot",
      })

      vim.keymap.set("i", "<C-q>", function()
        require("CopilotChat").trigger_complete()
      end, { desc = "Trigger Completion in Chat Window" })
    end,
  },
}
