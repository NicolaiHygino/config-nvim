-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- keep `scrolloff` padding past the end of the file, like VS Code's "scroll beyond last line"
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = vim.api.nvim_create_augroup("scroll_past_eof", { clear = true }),
  callback = function()
    if vim.bo.buftype ~= "" then
      return
    end
    local height = vim.api.nvim_win_get_height(0)
    local so = math.min(vim.wo.scrolloff, math.floor((height - 1) / 2))
    local rows_below = height - vim.fn.winline()
    if vim.fn.line("$") - vim.fn.line(".") < so and rows_below < so then
      local view = vim.fn.winsaveview()
      view.topline = math.min(view.topline + so - rows_below, view.lnum)
      vim.fn.winrestview(view)
    end
  end,
})
