return {
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        -- hide LSP progress messages (e.g. jdtls "Building", "Validate documents")
        progress = { enabled = false },
        -- don't auto-open signature help; <C-k> still shows it on demand
        signature = { auto_open = { enabled = false } },
      },
    },
  },
}
