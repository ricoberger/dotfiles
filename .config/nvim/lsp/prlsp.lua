-- Configuration for the "prlsp" language server, which surfaces GitHub PR
-- review comments in-editor as diagnostics. The server attaches to every file
-- inside a Git repository (no "filetypes" filter), so review comments can be
-- shown regardless of the file type.
--
-- The Lua API and ":PRLSP*" user commands live in "lua/core/prlsp.lua".
--
-- See: https://github.com/ricoberger/prlsp
return {
  cmd = { "prlsp" },
  root_markers = { ".git" },
}
