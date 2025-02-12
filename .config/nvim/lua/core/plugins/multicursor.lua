return {
  {
    "jake-stewart/multicursor.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local mc = require("multicursor-nvim")

      mc.setup()

      -- Add cursors above/below the main cursor.
      vim.keymap.set({ "n", "v" }, "<leader>m<up>", function()
        mc.addCursor("k")
      end, { desc = "Add Cursor (Up)" })
      vim.keymap.set({ "n", "v" }, "<leader>m<down>", function()
        mc.addCursor("j")
      end, { desc = "Add Cursor (Down)" })

      -- Add a cursor and jump to the next word under cursor.
      vim.keymap.set({ "n", "v" }, "<C-n>", function()
        mc.addCursor("*")
      end, { desc = "Multicursor" })
      vim.keymap.set({ "n", "v" }, "<leader>mn", function()
        mc.addCursor("*")
      end, { desc = "Add Cursor (Word)" })

      -- Add all matches in the document
      vim.keymap.set({ "n", "v" }, "<leader>mN", mc.matchAllAddCursors, { desc = "Add Cursor (Word - All)" })

      -- Jump to the next word under cursor but do not add a cursor.
      vim.keymap.set({ "n", "v" }, "<leader>ms", function()
        mc.skipCursor("*")
      end, { desc = "Skip Cursor (Word)" })

      -- Rotate the main cursor.
      vim.keymap.set({ "n", "v" }, "<leader>m<left>", mc.nextCursor, { desc = "Rotate Cursor (Next)" })
      vim.keymap.set({ "n", "v" }, "<leader>m<right>", mc.prevCursor, { desc = "Rotate Cursor (Prev)" })

      -- Delete the main cursor.
      vim.keymap.set({ "n", "v" }, "<leader>mx", mc.deleteCursor, { desc = "Delete Cursor" })

      vim.keymap.set("n", "<esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        elseif mc.hasCursors() then
          mc.clearCursors()
          vim.cmd("nohlsearch")
        else
          vim.cmd("nohlsearch")
        end
      end)

      -- bring back cursors if you accidentally clear them
      vim.keymap.set("n", "<leader>mr", mc.restoreCursors, { desc = "Restore Cursors" })

      -- Align cursor columns.
      vim.keymap.set("n", "<leader>ma", mc.alignCursors, { desc = "Align Cursors" })

      -- Split visual selections by regex.
      vim.keymap.set("v", "<leader>mS", mc.splitCursors, { desc = "Split Cursors" })

      -- Append/insert for each line of visual selections.
      vim.keymap.set("v", "<leader>mI", mc.insertVisual, { desc = "Insert Visual" })
      vim.keymap.set("v", "<leader>mA", mc.appendVisual, { desc = "Append Visual" })

      -- match new cursors within visual selections by regex.
      vim.keymap.set("v", "<leader>mM", mc.matchCursors, { desc = "Match Cursors" })

      -- Rotate visual selection contents.
      vim.keymap.set("v", "<leader>mt", function()
        mc.transposeCursors(1)
      end, { desc = "Rotate Clockwise" })
      vim.keymap.set("v", "<leader>mT", function()
        mc.transposeCursors(-1)
      end, { desc = "Rotate Anti-Clockwise" })

      -- Customize how cursors look.
      local hl = vim.api.nvim_set_hl
      hl(0, "MultiCursorCursor", { link = "Cursor" })
      hl(0, "MultiCursorVisual", { link = "Visual" })
      hl(0, "MultiCursorSign", { link = "SignColumn" })
      hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
      hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
      hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
    end,
  },
}
