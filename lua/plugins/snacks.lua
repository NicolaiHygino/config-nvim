local compact_folders = require("custom.compact_folders")

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    picker = {
      hidden = true,
      ignored = true,
      sources = {
        files = {
          hidden = true,
          ignored = true,
        },
        explorer = {
          layout = { layout = { width = 30, min_width = 30 } },
          -- compact folders (see lua/custom/compact_folders.lua)
          transform = compact_folders.transform,
          actions = compact_folders.actions,
          win = {
            list = {
              keys = compact_folders.keys,
            },
          },
        },
      },
    },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
    compact_folders.setup()
  end,
}
