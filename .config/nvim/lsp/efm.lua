local dartfmt = {
  formatCommand = "dart format --output show",
  formatStdin = true,
}

local gofmt = {
  formatCommand = "gofmt",
  formatStdin = true,
}

local goimports = {
  formatCommand = "goimports",
  formatStdin = true,
}

local jq = {
  formatCommand = "jq",
  formatStdin = true,
}

local prettier = {
  formatCanRange = true,
  formatCommand = "prettier --stdin --stdin-filepath '${INPUT}' ${--range-start:charStart} ${--range-end:charEnd} ${--tab-width:tabSize} ${--use-tabs:!insertSpaces} --config-precedence=file-override --prose-wrap=always --print-width=80",
  formatStdin = true,
}

local ruff = {
  formatCommand = "ruff format --no-cache --stdin-filename '${INPUT}'",
  formatStdin = true,
  rootMarkers = {
    "pyproject.toml",
    "setup.py",
    "requirements.txt",
    "ruff.toml",
  },
}

local rustfmt = {
  formatCommand = "rustfmt --emit=stdout",
  formatStdin = true,
}

local stylua = {
  formatCanRange = true,
  -- formatCommand = "stylua --config-path /Users/ricoberger/Documents/GitHub/ricoberger/dotfiles/stylua.toml --color Never ${--range-start:charStart} ${--range-end:charEnd} --stdin-filepath '${INPUT}' -",
  formatCommand = "stylua --search-parent-directories --color Never ${--range-start:charStart} ${--range-end:charEnd} --stdin-filepath '${INPUT}' -",
  formatStdin = true,
  rootMarkers = { "stylua.toml", ".stylua.toml" },
}

local terraformfmt = {
  formatCommand = "terraform fmt -",
  formatStdin = true,
}

local languages = {
  css = { prettier },
  dart = { dartfmt },
  html = { prettier },
  go = { gofmt, goimports },
  javascript = { prettier },
  javascriptreact = { prettier },
  json = { jq },
  lua = { stylua },
  markdown = { prettier },
  python = { ruff },
  rust = { rustfmt },
  terraform = { terraformfmt },
  typescript = { prettier },
  typescriptreact = { prettier },
  yaml = { prettier },
}

return {
  cmd = {
    "efm-langserver",
    -- "-logfile",
    -- "/Users/ricoberger/Desktop/efm.log",
    -- "-loglevel",
    -- "10",
  },
  init_options = {
    documentFormatting = true,
    documentRangeFormatting = true,
  },
  root_markers = { ".git" },
  filetypes = vim.tbl_keys(languages),
  settings = {
    rootMarkers = { ".git/" },
    languages = languages,
  },
}
