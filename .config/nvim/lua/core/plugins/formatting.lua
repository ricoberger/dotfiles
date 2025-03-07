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
        yaml = { "prettier" },
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
      },
      format_on_save = {
        timeout_ms = 1000,
        lsp_format = "fallback",
      },
    },
  },
}
