local icons = require("utils").icons

return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = icons.git.added },
          change = { text = icons.git.modified },
          delete = { text = icons.git.deleted },
          topdelete = { text = icons.git.deleted },
          changedelete = { text = icons.git.modified },
          untracked = { text = icons.git.untracked },
        },
        signs_staged = {
          add = { text = icons.git.added },
          change = { text = icons.git.deleted },
          delete = { text = icons.git.deleted },
          topdelete = { text = icons.git.deleted },
          changedelete = { text = icons.git.modified },
          untracked = { text = icons.git.untracked },
        },
        preview_config = {
          border = "single",
        },
        on_attach = function(bufnr)
          -- don't override the built-in keymaps
          local gs = package.loaded.gitsigns
          vim.keymap.set("n", "<leader>gs]c", function()
            if vim.wo.diff then
              return "]c"
            end
            vim.schedule(function()
              gs.next_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr, desc = "Jump to Next Hunk" })
          vim.keymap.set({ "n", "v" }, "<leader>gs[c", function()
            if vim.wo.diff then
              return "[c"
            end
            vim.schedule(function()
              gs.prev_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr, desc = "Jump to Previous Hunk" })

          -- Actions
          vim.keymap.set("n", "<leader>gss", ":Gitsigns stage_hunk<cr>", { desc = "Stage Hunk" })
          vim.keymap.set("n", "<leader>gsr", ":Gitsigns reset_hunk<cr>", { desc = "Reset Hunk" })
          vim.keymap.set("n", "<leader>gsS", gs.stage_buffer, { desc = "Stage all Hunks in Current Buffer" })
          vim.keymap.set("n", "<leader>gsR", gs.reset_buffer, { desc = "Reset all Hunk in Current Buffer" })
          vim.keymap.set("n", "<leader>gsu", gs.undo_stage_hunk, { desc = "Undo Last Hunk" })
          vim.keymap.set("n", "<leader>gsp", gs.preview_hunk, { desc = "Preview Hunk" })
          vim.keymap.set("n", "<leader>gsb", function()
            gs.blame_line({ full = false })
          end, { desc = "Git Blame (short)" })
          vim.keymap.set("n", "<leader>gsB", function()
            gs.blame_line({ full = true })
          end, { desc = "Git Blame (full)" })
          vim.keymap.set("n", "<leader>gsd", gs.toggle_deleted, { desc = "Toggle Deleted" })
          vim.keymap.set("n", "<leader>gsq", ":Gitsigns setqflist<cr>", { desc = "Quickfix List" })
          vim.keymap.set("n", "<leader>gsl", ":Gitsigns setloclist<cr>", { desc = "Location List" })
        end,
      })
    end,
  },
  {
    "sindrets/diffview.nvim",
    opts = {},
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    keys = {
      { "<leader>gdo", "<cmd>DiffviewOpen<cr>", desc = "Open" },
      { "<leader>gdO", "<cmd>DiffviewOpen origin/HEAD...HEAD --imply-local<cr>", desc = "Open (HEAD)" },
      { "<leader>gdC", "<cmd>DiffviewClose<cr>", desc = "Close" },
      { "<leader>gdt", "<cmd>DiffviewToggleFiles<cr>", desc = "Toggle Files" },
      { "<leader>gdf", "<cmd>DiffviewFocusFiles<cr>", desc = "Focus Files" },
      { "<leader>gdhb", "<cmd>DiffviewFileHistory<cr>", desc = "Branch History" },
      { "<leader>gdhf", "<cmd>DiffviewFileHistory %<cr>", desc = "File History" },
    },
    config = function()
      local actions = require("diffview.actions")
      require("diffview").setup({
        keymaps = {
          disable_defaults = true,
          view = {
            { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<s-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
            { "n", "<leader>gdx", actions.cycle_layout, { desc = "Cycle through available layouts." } },
            { "n", "[x", actions.prev_conflict, { desc = "Jump to the previous conflict" } },
            { "n", "]x", actions.next_conflict, { desc = "Jump to the next conflict" } },
            {
              "n",
              "<leader>gdco",
              actions.conflict_choose("ours"),
              { desc = "Choose the OURS version of a conflict" },
            },
            {
              "n",
              "<leader>gdct",
              actions.conflict_choose("theirs"),
              { desc = "Choose the THEIRS version of a conflict" },
            },
            {
              "n",
              "<leader>gdcb",
              actions.conflict_choose("base"),
              { desc = "Choose the BASE version of a conflict" },
            },
            { "n", "<leader>gdca", actions.conflict_choose("all"), { desc = "Choose all the versions of a conflict" } },
            { "n", "<leader>gdcx", actions.conflict_choose("none"), { desc = "Delete the conflict region" } },
            {
              "n",
              "<leader>gdcO",
              actions.conflict_choose_all("ours"),
              {
                desc = "Choose the OURS version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcT",
              actions.conflict_choose_all("theirs"),
              {
                desc = "Choose the THEIRS version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcB",
              actions.conflict_choose_all("base"),
              {
                desc = "Choose the BASE version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcA",
              actions.conflict_choose_all("all"),
              {
                desc = "Choose all the versions of a conflict for the whole file",
              },
            },
            {
              "n",
              "gdcX",
              actions.conflict_choose_all("none"),
              {
                desc = "Delete the conflict region for the whole file",
              },
            },
          },
          file_panel = {
            {
              "n",
              "j",
              actions.next_entry,
              {
                desc = "Bring the cursor to the next file entry",
              },
            },
            {
              "n",
              "<down>",
              actions.next_entry,
              {
                desc = "Bring the cursor to the next file entry",
              },
            },
            {
              "n",
              "k",
              actions.prev_entry,
              {
                desc = "Bring the cursor to the previous file entry",
              },
            },
            {
              "n",
              "<up>",
              actions.prev_entry,
              {
                desc = "Bring the cursor to the previous file entry",
              },
            },
            { "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
            { "n", "s", actions.toggle_stage_entry, { desc = "Stage / unstage the selected entry" } },
            { "n", "S", actions.stage_all, { desc = "Stage all entries" } },
            { "n", "U", actions.unstage_all, { desc = "Unstage all entries" } },
            {
              "n",
              "X",
              actions.restore_entry,
              {
                desc = "Restore entry to the state on the left side",
              },
            },
            { "n", "L", actions.open_commit_log, { desc = "Open the commit log panel" } },
            { "n", "zo", actions.open_fold, { desc = "Expand fold" } },
            { "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
            { "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
            { "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
            { "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
            { "n", "<c-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
            { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
            { "n", "<s-tab>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
            {
              "n",
              "i",
              actions.listing_style,
              {
                desc = "Toggle between 'list' and 'tree' views",
              },
            },
            {
              "n",
              "f",
              actions.toggle_flatten_dirs,
              {
                desc = "Flatten empty subdirectories in tree listing style",
              },
            },
            {
              "n",
              "R",
              actions.refresh_files,
              {
                desc = "Update stats and entries in the file list",
              },
            },
            { "n", "<leader>gdx", actions.cycle_layout, { desc = "Cycle through available layouts." } },
            { "n", "[x", actions.prev_conflict, { desc = "Go to the previous conflict" } },
            { "n", "]x", actions.next_conflict, { desc = "Go to the next conflict" } },
            {
              "n",
              "<leader>gdcO",
              actions.conflict_choose_all("ours"),
              {
                desc = "Choose the OURS version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcT",
              actions.conflict_choose_all("theirs"),
              {
                desc = "Choose the THEIRS version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcB",
              actions.conflict_choose_all("base"),
              {
                desc = "Choose the BASE version of a conflict for the whole file",
              },
            },
            {
              "n",
              "<leader>gdcA",
              actions.conflict_choose_all("all"),
              {
                desc = "Choose all the versions of a conflict for the whole file",
              },
            },
            {
              "n",
              "gdcX",
              actions.conflict_choose_all("none"),
              {
                desc = "Delete the conflict region for the whole file",
              },
            },
          },
          file_history_panel = {
            { "n", "g!", actions.options, { desc = "Open the option panel" } },
            {
              "n",
              "<C-A-d>",
              actions.open_in_diffview,
              {
                desc = "Open the entry under the cursor in a diffview",
              },
            },
            {
              "n",
              "y",
              actions.copy_hash,
              {
                desc = "Copy the commit hash of the entry under the cursor",
              },
            },
            { "n", "L", actions.open_commit_log, { desc = "Show commit details" } },
            {
              "n",
              "X",
              actions.restore_entry,
              {
                desc = "Restore file to the state from the selected entry",
              },
            },
            { "n", "zo", actions.open_fold, { desc = "Expand fold" } },
            { "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
            { "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
            { "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
            { "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
            { "n", "j", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
            { "n", "<down>", actions.next_entry, { desc = "Bring the cursor to the next file entry" } },
            {
              "n",
              "k",
              actions.prev_entry,
              {
                desc = "Bring the cursor to the previous file entry",
              },
            },
            {
              "n",
              "<up>",
              actions.prev_entry,
              {
                desc = "Bring the cursor to the previous file entry",
              },
            },
            {
              "n",
              "<cr>",
              actions.select_entry,
              { desc = "Open the diff for the selected entry" },
            },
            { "n", "<c-b>", actions.scroll_view(-0.25), { desc = "Scroll the view up" } },
            { "n", "<c-f>", actions.scroll_view(0.25), { desc = "Scroll the view down" } },
            { "n", "<tab>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
            {
              "n",
              "<s-tab>",
              actions.select_prev_entry,
              { desc = "Open the diff for the previous file" },
            },
            { "n", "<leader>gdx", actions.cycle_layout, { desc = "Cycle through available layouts." } },
          },
          option_panel = {
            { "n", "<tab>", actions.select_entry, { desc = "Change the current option" } },
            { "n", "q", actions.close, { desc = "Close the panel" } },
            { "n", "<esc>", actions.close, { desc = "Close the panel" } },
          },
          help_panel = {
            { "n", "q", actions.close, { desc = "Close help menu" } },
            { "n", "<esc>", actions.close, { desc = "Close help menu" } },
          },
        },
      })
    end,
  },
}
