return {
  -- Use my custom build of yaml-language-server, were the default Kubernetes
  -- schema can be set via the "YAMLLS_KUBERNETES_SCHEMA_URL" environemnt
  -- variable.
  --
  -- See: https://github.com/ricoberger/yaml-language-server/pull/1
  --
  -- This was done to be able to combine the Kubernetes schema with the schema
  -- of CustomResourceDefinitions (CRDs), to have a better experience with the
  -- yaml-language-server when working with Kubernetes manifests.
  --
  -- See: https://github.com/ricoberger/kubernetes-json-schema
  --
  -- cmd = { "yaml-language-server", "--stdio" },
  cmd = {
    "node",
    "/Users/ricoberger/Documents/GitHub/ricoberger/yaml-language-server/out/server/src/server.js",
    "--stdio",
  },
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
