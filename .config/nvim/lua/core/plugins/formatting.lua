return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      formatters_by_ft = {
        css = { "prettier" },
        dart = { "dart_format" },
        html = { "prettier" },
        json = { "jq" },
        go = { "gofmt", "goimports" },
        lua = { "stylua" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        rust = { "rustfmt" },
        terraform = { "terraform_fmt" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "yamlfmt" },
        ["*"] = { "trim_newlines", "trim_whitespace" },
      },
      formatters = {
        yamlfmt = {
          prepend_args = {
            "-formatter",
            "include_document_start=true,indentless_arrays=false,retain_line_breaks=true,eof_newline=true,scan_folded_as_literal=true",
          },
        },
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
      },
    },
  },
}
