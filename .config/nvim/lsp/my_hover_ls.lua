-- Preview urls in Markdown files inside Neovim with "K" using a custom LSP
-- server that fetches the markdown content of the url via markdown.new and
-- displays it in the hover window.
--
-- See: https://www.reddit.com/r/neovim/comments/1rnkqkv/preview_urls_as_markdown_with_lsp_hovers/
local ms = vim.lsp.protocol.Methods

local capabilities = {
  capabilities = {
    hoverProvider = true,
  },
  serverInfo = {
    name = "my_hover_ls",
    version = "0.0.1",
  },
}

local function cursor_is_url()
  local urls = vim.ui._get_urls()

  if not vim.tbl_isempty(urls) and vim.startswith(urls[1], "https://") then
    return true, urls[1]
  end
  return false, nil
end

local cache = {}

-- TODO: make async once the vim.spinner is available, and display a spinner
-- while fetching the content
local function fetch_markdown(url)
  if cache[url] then
    return cache[url]
  end
  local out =
    vim.system({ "curl", "-s", "https://markdown.new/" .. url }):wait()
  if out.code == 0 then
    cache[url] = out.stdout
    -- NOTE: pipe through a markdown formatter here?
    return out.stdout
  else
    return "Failed to fetch markdown content."
  end
end

return {
  cmd = function()
    return {
      request = function(method, _, handler, _)
        if method == ms.textDocument_hover then
          local is_url, url = cursor_is_url()
          -- other type of symbols you want to hover
          if is_url then
            handler(nil, {
              contents = {
                kind = "markdown",
                value = fetch_markdown(url),
              },
            })
          end
        elseif method == ms.initialize then
          handler(nil, capabilities)
        end
      end,
      notify = function() end,
      is_closing = function() end,
      terminate = function() end,
    }
  end,
  filetypes = { "markdown" },
}
