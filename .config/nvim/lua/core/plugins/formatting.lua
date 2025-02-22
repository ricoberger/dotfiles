return {
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      formatters_by_ft = {
        css = { "prettier" },
        dart = { "dart_format" },
        html = { "prettier" },
        go = { "gofmt", "goimports" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "jq" },
        lua = { "stylua" },
        markdown = { "prettier" },
        rust = { "rustfmt" },
        terraform = { "terraform_fmt" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        yaml = { "yamlfmt" },
        ["*"] = { "trim_newlines", "trim_whitespace" },
      },
      formatters = {
        prettier = {
          prepend_args = {
            "--prose-wrap",
            "always",
            "--print-width",
            "80",
          },
        },
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
