return {
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      -- Explicitly tell LazyVim's Java extra to load the test bundles
      test = false,
      settings = {
        java = {
          -- jdtls doesn't advertise signatureHelp unless this is enabled
          signatureHelp = { enabled = true },
        },
      },
    },
  },
}
