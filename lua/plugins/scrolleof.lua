return {
  {
    -- keep `scrolloff` padding past the end of the file, like VS Code's "scroll beyond last line"
    "Aasim-A/scrollEOF.nvim",
    lazy = false,
    opts = {
      insert_mode = true, -- also pad while typing at the end of the file
    },
  },
}
