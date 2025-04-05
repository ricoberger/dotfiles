return {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = {
    "go.mod",
    "go.sum",
  },
  single_file_support = true,
}
