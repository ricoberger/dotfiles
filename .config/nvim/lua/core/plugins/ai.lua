return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    build = ":Copilot auth",
    event = "InsertEnter",
    opts = {
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "bottom",
          ratio = 0.4,
        },
      },
      suggestion = {
        enabled = true,
        auto_trigger = true,
        hide_during_completion = true,
        debounce = 75,
        trigger_on_accept = true,
        keymap = {
          accept = "<C-CR>",
          accept_word = false,
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = false,
        },
      },
      filetypes = {
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["*"] = true,
      },
    },
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    version = "*",
    branch = "main",
    dependencies = {
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
