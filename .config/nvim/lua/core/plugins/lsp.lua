return {
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "saghen/blink.cmp",
      {
        "towolf/vim-helm",
        ft = { "helm" },
      },
    },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- Servers:
      --   npm install -g vscode-langservers-extracted@4.8.0
      --   go install golang.org/x/tools/gopls@latest
      --   brew install helm-ls
      --   brew install lua-language-server
      --   brew install marksman
      --   brew install hashicorp/tap/terraform-ls
      --   npm install -g typescript-language-server typescript
      --   npm install -g yaml-language-server
      --
      -- See: https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
      servers = {
        dartls = {},
        denols = {
          root_dir = function(fname)
            local lspconfig = require("lspconfig")
            return lspconfig.util.root_pattern("deno.json", "deno.jsonc", "import_map.json")(fname)
          end,
        },
        eslint = {},
        gopls = {},
        helm_ls = {},
        lua_ls = {
          settings = {
            Lua = {
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        marksman = {},
        terraformls = {},
        ts_ls = {
          root_dir = function(fname)
            local lspconfig = require("lspconfig")
            return lspconfig.util.root_pattern("package.json")(fname) or lspconfig.util.find_git_ancestor(fname)
          end,
          single_file_support = false,
        },
        yamlls = {},
      },
    },
    config = function(_, opts)
      local lspconfig = require("lspconfig")
      for server, config in pairs(opts.servers) do
        -- passing config.capabilities to blink.cmp merges with the capabilities in your
        -- `opts[server].capabilities, if you've defined it
        config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
        lspconfig[server].setup(config)
      end

      vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, { desc = "Rename" })
      vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, { desc = "Actions" })
      vim.keymap.set("n", "<leader>lf", vim.lsp.buf.format, { desc = "Format" })
      vim.keymap.set("n", "<leader>lq", vim.diagnostic.setqflist, { desc = "Quickfix List" })
      vim.keymap.set("n", "<leader>lL", vim.diagnostic.setloclist, { desc = "Location List" })
      vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover Documentation" })
      vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, { desc = "Hover Signature Documentation" })
      vim.keymap.set("n", "J", vim.diagnostic.open_float, { desc = "Hover Diagnostics" })
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { desc = "Go to Declaration" })
      vim.keymap.set("n", "gd", function()
        Snacks.picker.lsp_definitions()
      end, { desc = "Go to Definitions" })
      vim.keymap.set("n", "gr", function()
        Snacks.picker.lsp_references()
      end, { desc = "Go to References" })
      vim.keymap.set("n", "gI", function()
        Snacks.picker.lsp_implementations()
      end, { desc = "Go to Implementation" })
      vim.keymap.set("n", "gy", function()
        Snacks.picker.lsp_type_definitions()
      end, { desc = "Go to Type Definition" })
    end,
  },
}
