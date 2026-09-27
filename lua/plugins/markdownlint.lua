-- Global markdownlint-cli2 config (disables MD013 line-length, etc.)
local config = vim.fn.expand("~/.config/markdownlint/.markdownlint-cli2.yaml")

return {
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = { "--config", config, "-" },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", config },
        },
      },
    },
  },
}
