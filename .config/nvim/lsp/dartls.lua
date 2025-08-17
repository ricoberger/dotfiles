return {
  cmd = {
    "dart",
    "language-server",
    "--protocol=lsp",
    -- "--instrumentation-log-file=/Users/ricoberger/Desktop/dartls.log",
  },
  filetypes = { "dart" },
  root_markers = { "pubspec.yaml" },
  init_options = {
    onlyAnalyzeProjectsWithOpenFiles = true,
    suggestFromUnimportedLibraries = true,
    closingLabels = true,
    outline = true,
    flutterOutline = true,
  },
  settings = {
    dart = {
      completeFunctionCalls = true,
      showTodos = true,
    },
  },
}
