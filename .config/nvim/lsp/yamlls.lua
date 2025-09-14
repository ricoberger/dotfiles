return {
  -- See: ./.local/bin/yamlls
  -- cmd = { "yaml-language-server", "--stdio" },
  cmd = { "yamlls", "--stdio" },
  filetypes = {
    "yaml",
    "yaml.docker-compose",
    "yaml.gitlab",
    "yaml.helm-values",
  },
  single_file_support = true,
  settings = {
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    yaml = {
      format = {
        enable = false,
      },
      completion = true,
      hover = true,
      validate = true,
      schemas = {
        kubernetes = {
          "/kubernetes/**/*.yml",
          "/kubernetes/**/*.yaml",
        },
        ["https://www.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
        ["https://www.schemastore.org/github-action.json"] = ".github/action.{yml,yaml}",
        ["https://www.schemastore.org/github-workflow.json"] = ".github/workflows/*.{yml,yaml}",
        ["https://www.schemastore.org/chart.json"] = "Chart.{yml,yaml}",
        ["https://www.schemastore.org/dependabot-2.0.json"] = ".github/dependabot.{yml,yaml}",
        ["https://www.schemastore.org/prettierrc.json"] = ".prettierrc.{yml,yaml}",
        ["https://raw.githubusercontent.com/compose-spec/compose-go/master/schema/compose-spec.json"] = "*docker-compose*.{yml,yaml}",
      },
      schemaStore = {
        enable = false,
        url = "",
      },
    },
  },
  on_init = function(client)
    client.server_capabilities.documentFormattingProvider = nil
    client.server_capabilities.documentRangeFormattingProvider = nil
  end,
}
