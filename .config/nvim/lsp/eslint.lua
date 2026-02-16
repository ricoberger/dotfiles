-- See: https://github.com/neovim/nvim-lspconfig/blob/master/lsp/eslint.lua
local eslint_config_files = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  ".eslintrc.json",
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue",
    "svelte",
    "astro",
    "htmlangular",
  },
  workspace_required = true,
  on_attach = function(client, bufnr)
    vim.api.nvim_buf_create_user_command(bufnr, "LspEslintFixAll", function()
      client:request_sync("workspace/executeCommand", {
        command = "eslint.applyAllFixes",
        arguments = {
          {
            uri = vim.uri_from_bufnr(bufnr),
            version = vim.lsp.util.buf_versions[bufnr],
          },
        },
      }, nil, bufnr)
    end, {})
  end,
  root_dir = function(bufnr, on_dir)
    local function root_markers_with_field(root_files, new_names, field, fname)
      local path = vim.fn.fnamemodify(fname, ":h")
      local found = vim.fs.find(new_names, { path = path, upward = true })

      for _, f in ipairs(found or {}) do
        -- Match the given `field`.
        for line in io.lines(f) do
          if line:find(field) then
            root_files[#root_files + 1] = vim.fs.basename(f)
            break
          end
        end
      end

      return root_files
    end

    local function insert_package_json(root_files, field, fname)
      return root_markers_with_field(
        root_files,
        { "package.json", "package.json5" },
        field,
        fname
      )
    end

    -- The project root is where the LSP can be started from
    -- As stated in the documentation above, this LSP supports monorepos and simple projects.
    -- We select then from the project root, which is identified by the presence of a package
    -- manager lock file.
    local root_markers = {
      "package-lock.json",
      "yarn.lock",
      "pnpm-lock.yaml",
      "bun.lockb",
      "bun.lock",
    }
    -- Give the root markers equal priority by wrapping them in a table
    root_markers = vim.fn.has("nvim-0.11.3") == 1
        and { root_markers, { ".git" } }
      or vim.list_extend(root_markers, { ".git" })

    -- exclude deno
    if vim.fs.root(bufnr, { "deno.json", "deno.jsonc", "deno.lock" }) then
      return
    end

    -- We fallback to the current working directory if no project root is found
    local project_root = vim.fs.root(bufnr, root_markers) or vim.fn.getcwd()

    -- We know that the buffer is using ESLint if it has a config file
    -- in its directory tree.
    --
    -- Eslint used to support package.json files as config files, but it doesn't anymore.
    -- We keep this for backward compatibility.
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local eslint_config_files_with_package_json =
      insert_package_json(eslint_config_files, "eslintConfig", filename)
    local is_buffer_using_eslint =
      vim.fs.find(eslint_config_files_with_package_json, {
        path = filename,
        type = "file",
        limit = 1,
        upward = true,
        stop = vim.fs.dirname(project_root),
      })[1]
    if not is_buffer_using_eslint then
      return
    end

    on_dir(project_root)
  end,
  -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation.
  settings = {
    validate = "on",
    packageManager = nil,
    useESLintClass = false,
    experimental = {
      useFlatConfig = false,
    },
    codeActionOnSave = {
      enable = false,
      mode = "all",
    },
    format = true,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = {
      shortenToSingleLine = false,
    },
    -- nodePath configures the directory in which the eslint server should start its node_modules resolution.
    -- This path is relative to the workspace folder (root dir) of the server instance.
    nodePath = "",
    -- use the workspace folder location or the file location (if no workspace folder is open) as the working directory
    workingDirectory = { mode = "auto" },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = "separateLine",
      },
      showDocumentation = {
        enable = true,
      },
    },
  },
  before_init = function(_, config)
    -- The "workspaceFolder" is a VSCode concept. It limits how far the
    -- server will traverse the file system when locating the ESLint config
    -- file (e.g., .eslintrc).
    local root_dir = config.root_dir

    if root_dir then
      config.settings = config.settings or {}
      config.settings.workspaceFolder = {
        uri = root_dir,
        name = vim.fn.fnamemodify(root_dir, ":t"),
      }

      -- Support flat config files
      -- They contain 'config' in the file name
      local flat_config_files = vim.tbl_filter(function(file)
        return file:match("config")
      end, eslint_config_files)

      for _, file in ipairs(flat_config_files) do
        local found_files = vim.fn.globpath(root_dir, file, true, true)

        -- Filter out files inside node_modules
        local filtered_files = {}
        for _, found_file in ipairs(found_files) do
          if string.find(found_file, "[/\\]node_modules[/\\]") == nil then
            table.insert(filtered_files, found_file)
          end
        end

        if #filtered_files > 0 then
          config.settings.experimental = config.settings.experimental or {}
          config.settings.experimental.useFlatConfig = true
          break
        end
      end

      -- Support Yarn2 (PnP) projects
      local pnp_cjs = root_dir .. "/.pnp.cjs"
      local pnp_js = root_dir .. "/.pnp.js"
      if
        type(config.cmd) == "table"
        and (vim.uv.fs_stat(pnp_cjs) or vim.uv.fs_stat(pnp_js))
      then
        config.cmd =
          vim.list_extend({ "yarn", "exec" }, config.cmd --[[@as table]])
      end
    end
  end,
  handlers = {
    ["eslint/openDoc"] = function(_, result)
      if result then
        vim.ui.open(result.url)
      end
      return {}
    end,
    ["eslint/confirmESLintExecution"] = function(_, result)
      if not result then
        return
      end
      return 4 -- approved
    end,
    ["eslint/probeFailed"] = function()
      vim.notify("[lspconfig] ESLint probe failed.", vim.log.levels.WARN)
      return {}
    end,
    ["eslint/noLibrary"] = function()
      vim.notify(
        "[lspconfig] Unable to find ESLint library.",
        vim.log.levels.WARN
      )
      return {}
    end,
  },
}
