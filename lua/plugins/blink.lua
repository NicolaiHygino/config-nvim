return {
  "saghen/blink.cmp",
  opts = {
    -- don't pop up signature help while typing; open it manually with <C-k>
    signature = { enabled = true, trigger = { enabled = false } },
    completion = {
      list = {
        selection = {
          preselect = false,
          auto_insert = false,
        },
      },
      trigger = {
        show_on_keyword = true,
        show_on_insert_on_trigger_character = true,
        debounce = 150,
      },
    },
    keymap = {
      preset = "none",
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<Tab>"] = { "select_next", "fallback" },
      ["<S-Tab>"] = { "select_prev", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
    },
  },
}
