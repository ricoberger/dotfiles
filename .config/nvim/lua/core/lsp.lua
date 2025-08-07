-- See: https://github.com/neovim/nvim-lspconfig/tree/master/lua/lspconfig/configs

vim.api.nvim_create_autocmd("LspAttach", {
  desc = "LSP Actions",
  callback = function(event)
    vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { buffer = event.buf, desc = "Rename" })
    vim.keymap.set("n", "<leader>lca", vim.lsp.buf.code_action, { buffer = event.buf, desc = "Code Actions" })
    vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, { buffer = event.buf, desc = "Format" })
    vim.keymap.set("n", "<leader>lq", vim.diagnostic.setqflist, { buffer = event.buf, desc = "Quickfix List" })
    vim.keymap.set("n", "<leader>lL", vim.diagnostic.setloclist, { buffer = event.buf, desc = "Location List" })
    vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = event.buf, desc = "Hover Documentation" })
    vim.keymap.set("n", "J", vim.diagnostic.open_float, { buffer = event.buf, desc = "Hover Diagnostics" })
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = event.buf, desc = "Go to Declaration" })
    vim.keymap.set("n", "gd", function()
      Snacks.picker.lsp_definitions()
    end, { buffer = event.buf, desc = "Go to Definitions" })
    vim.keymap.set("n", "gv", function()
      vim.cmd([[ vsplit ]])
      vim.lsp.buf.definition()
    end, { buffer = event.buf, desc = "Go to Definitions" })
    vim.keymap.set("n", "gR", function()
      Snacks.picker.lsp_references()
    end, { buffer = event.buf, desc = "Go to References" })
    vim.keymap.set("n", "gI", function()
      Snacks.picker.lsp_implementations()
    end, { buffer = event.buf, desc = "Go to Implementation" })
    vim.keymap.set("n", "gy", function()
      Snacks.picker.lsp_type_definitions()
    end, { buffer = event.buf, desc = "Go to Type Definition" })
  end,
})

local capabilities = {
  textDocument = {
    foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    },
  },
}

capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)

vim.lsp.config("*", {
  capabilities = capabilities,
  root_markers = { ".git" },
})

vim.lsp.enable({
  "dartls",
  "denols",
  "dockerls",
  "docker_compose_language_service",
  "eslint",
  "gopls",
  "helm_ls",
  "kotlin_lsp",
  "lua_ls",
  "marksman",
  "terraformls",
  "ts_ls",
  "yamlls",
})
