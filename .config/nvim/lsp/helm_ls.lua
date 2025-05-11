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
}
