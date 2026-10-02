return {
  {
    "rcarriga/nvim-dap-ui",
    -- Replaces LazyVim's config, which also closes the UI when the program
    -- exits and takes its console output with it. Close it with <leader>du.
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
    end,
  },
}
