return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".luarc.json",
    ".luarc.jsonc",
    ".luacheckrc",
    ".stylua.toml",
    "stylua.toml",
    "selene.toml",
    "selene.yml",
  },
  single_file_support = true,
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        -- Index the Neovim runtime so that annotations referencing built-in
        -- types (e.g. "vim.lsp.Client", "lsp.HandlerContext") resolve.
        library = { vim.env.VIMRUNTIME .. "/lua" },
      },
      telemetry = { enable = false },
      diagnostics = { globals = { "vim" } },
      format = { enable = false },
    },
  },
}
