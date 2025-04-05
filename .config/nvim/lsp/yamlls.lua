return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  single_file_support = true,
  settings = {
    redhat = { telemetry = { enabled = false } },
  },
}
