-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
-- the terminal of the last `<leader>r` run, closed before the next one starts
local run_term
-- the arguments last given to `<leader>ra`, per file
local run_args_by_file = {}

-- run `cmd` (the program and its file, already shell-escaped) in a terminal
-- docked at the bottom, from the file's folder. `run_args` is passed through
-- the shell, so it can quote arguments that contain spaces.
local function run_file(file, cmd, run_args)
  vim.cmd("update")
  if run_term and run_term:buf_valid() then
    run_term:close()
  end
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
  run_term = term
end

-- add `<leader>rr` and `<leader>ra` to `buf`, running its file with the
-- command `get_cmd(file)` returns
local function map_run_file(buf, lang, get_cmd)
  local file = vim.api.nvim_buf_get_name(buf)
  require("which-key").add({ { "<leader>r", group = "run", buffer = buf } })
  vim.keymap.set("n", "<leader>rr", function()
    run_file(file, get_cmd(file))
  end, { buffer = buf, desc = "Run " .. lang .. " File" })
  vim.keymap.set("n", "<leader>ra", function()
    vim.ui.input({ prompt = "Arguments: ", default = run_args_by_file[file] }, function(input)
      if input == nil then
        return
      end
      run_args_by_file[file] = input
      run_file(file, get_cmd(file), input)
    end)
  end, { buffer = buf, desc = "Run " .. lang .. " File with Arguments" })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function(args)
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true

    -- the JDK's source launcher (`java Main.java`) also compiles the other
    -- sources of the file's package tree
    map_run_file(args.buf, "Java", function(file)
      return "java " .. vim.fn.shellescape(file)
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function(args)
    -- prefer the project's `.venv` when no virtualenv is active in Neovim
    -- (e.g. one picked with venv-selector, which puts it first on PATH)
    map_run_file(args.buf, "Python", function(file)
      local python = "python3"
      if not vim.env.VIRTUAL_ENV then
        local venv = vim.fs.find(".venv", { path = vim.fs.dirname(file), upward = true, type = "directory" })[1]
        if venv and vim.fn.executable(venv .. "/bin/python") == 1 then
          python = vim.fn.shellescape(venv .. "/bin/python")
        end
      end
      return python .. " " .. vim.fn.shellescape(file)
    end)
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
