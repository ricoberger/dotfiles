return {
  cmd = { "helm_ls", "serve" },
  filetypes = { "helm" },
  root_markers = { "Chart.yaml" },
  workspace_required = true,
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
      },
    },
  },
  settings = {
    ["helm-ls"] = {
      -- See: .config/nvim/lsp/yamlls.lua
      -- See: ./.local/bin/yamlls
      yamlls = {
        path = "yamlls",
        config = {
          format = {
            enable = false,
          },
          completion = true,
          hover = true,
          validate = true,
          schemas = {
            kubernetes = {
              "/charts/**/*.yml",
              "/charts/**/*.yaml",
            },
          },
          schemaStore = {
            enable = false,
            url = "",
          },
        },
      },
    },
  },
}
