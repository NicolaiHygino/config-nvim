-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- the terminal of the last `<leader>r` run, closed before the next one starts
local java_run_term
-- the arguments last given to `<leader>ra`, per file
local java_run_args = {}

-- run a file with the JDK's source launcher (`java Main.java`), which also
-- compiles the other sources of its package tree. `run_args` is passed through
-- the shell, so it can quote arguments that contain spaces.
local function java_run(file, run_args)
  vim.cmd("update")
  if java_run_term and java_run_term:buf_valid() then
    java_run_term:close()
  end
  local cmd = "java " .. vim.fn.shellescape(file)
  if run_args and run_args ~= "" then
    cmd = cmd .. " " .. run_args
  end
  local term = Snacks.terminal.open(cmd, {
    cwd = vim.fs.dirname(file),
    auto_close = false, -- keep the output after the program exits
    -- a finished terminal closes on any key typed in terminal mode, so
    -- don't re-enter it when focusing the window, and leave it on exit
    auto_insert = false,
    win = { position = "bottom" }, -- docked like <leader>ft, not floating
  })
  term:on("TermClose", function()
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() == term.buf then
        vim.cmd.stopinsert()
      end
    end)
  end, { buf = true })
  java_run_term = term
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(args)
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true

    local file = vim.api.nvim_buf_get_name(args.buf)
    require("which-key").add({ { "<leader>r", group = "run", buffer = args.buf } })
    vim.keymap.set("n", "<leader>rr", function()
      java_run(file)
    end, { buffer = args.buf, desc = "Run Java File" })
    vim.keymap.set("n", "<leader>ra", function()
      vim.ui.input({ prompt = "Arguments: ", default = java_run_args[file] }, function(input)
        if input == nil then
          return
        end
        java_run_args[file] = input
        java_run(file, input)
      end)
    end, { buffer = args.buf, desc = "Run Java File with Arguments" })
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
