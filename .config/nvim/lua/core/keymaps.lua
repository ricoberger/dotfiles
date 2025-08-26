-- Better up/down
vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Move to window using the <ctrl> arrow keys
vim.keymap.set("n", "<C-Left>", "<C-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("n", "<C-Down>", "<C-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("n", "<C-Up>", "<C-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("n", "<C-Right>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Move to window using the <ctrl> hjkl keys
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window", remap = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window", remap = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window", remap = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Resize window using <shift> arrow keys
vim.keymap.set("n", "<S-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<S-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<S-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<S-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move to next / previous buffer
-- vim.keymap.set("n", "<TAB>", ":bn<CR>", { desc = "Next buffer" })
-- vim.keymap.set("n", "<S-TAB>", ":bp<CR>", { desc = "Previous buffer" })

-- Move Lines
vim.keymap.set("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
vim.keymap.set("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
vim.keymap.set("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
vim.keymap.set("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

-- Better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- Clear search with <esc>
vim.keymap.set({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- Surround
vim.keymap.set("v", "gs(", "<esc>`>a)<esc>`<i(<esc>", { desc = "Add () around selection" })
vim.keymap.set("v", "gs)", "<esc>`>a)<esc>`<i(<esc>", { desc = "Add () around selection" })
vim.keymap.set("v", "gs{", "<esc>`>a}<esc>`<i{<esc>", { desc = "Add {} around selection" })
vim.keymap.set("v", "gs}", "<esc>`>a}<esc>`<i{<esc>", { desc = "Add {} around selection" })
vim.keymap.set("v", "gs[", "<esc>`>a]<esc>`<i[<esc>", { desc = "Add [] around selection" })
vim.keymap.set("v", "gs]", "<esc>`>a]<esc>`<i[<esc>", { desc = "Add [] around selection" })
vim.keymap.set("v", "gs<", "<esc>`>a><esc>`<i<<esc>", { desc = "Add <> around selection" })
vim.keymap.set("v", "gs>", "<esc>`>a><esc>`<i<<esc>", { desc = "Add <> around selection" })
vim.keymap.set("v", 'gs"', '<esc>`>a"<esc>`<i"<esc>', { desc = 'Add "" around selection' })
vim.keymap.set("v", "gs'", "<esc>`>a'<esc>`<i'<esc>", { desc = "Add '' around selection" })
vim.keymap.set("v", "gs`", "<esc>`>a`<esc>`<i`<esc>", { desc = "Add `` around selection" })

-- Search and replace
vim.keymap.set("n", "<leader>rr", [[:%s///gcI<Left><Left><Left><Left><Left>]], { desc = "Replace in Buffer" })
vim.keymap.set(
  "n",
  "<leader>rw",
  [[:%s/\<<C-r><C-w>\>//gcI<Left><Left><Left><Left>]],
  { desc = "Replace in Buffer (Word)" }
)
vim.keymap.set(
  "n",
  "<leader>rR",
  [[:cfdo %s///gcI | update]]
    .. [[<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>]],
  { desc = "Replace in Quickfix List" }
)
vim.keymap.set(
  "n",
  "<leader>rW",
  [[:cfdo %s/\<<C-r><C-w>\>//gcI | update]]
    .. [[<Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left><Left>]],
  { desc = "Replace in Quickfix List (Word)" }
)
