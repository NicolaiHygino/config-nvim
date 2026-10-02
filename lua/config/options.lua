-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.scrolloff = 8 -- also sets the padding after the last line (see scroll_past_eof in autocmds.lua)

-- jdtls roots loose Java files at their own folder (see plugins/java.lua) so the
-- debugger runs next to them, but the root used by the explorer and pickers
-- should keep jdtls' default rule: the nearest build wrapper or git repo.
vim.g.root_lsp_ignore = { "copilot", "jdtls" }
vim.g.root_spec = {
  function(buf)
    if vim.bo[buf].filetype == "java" then
      return vim.fs.root(buf, vim.lsp.config.jdtls.root_markers)
    end
  end,
  "lsp",
  { ".git", "lua" },
  "cwd",
}
