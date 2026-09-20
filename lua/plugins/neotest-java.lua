return {
  { "rcasia/neotest-java" },
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        ["neotest-java"] = {
          junit_jar = nil,
          jvm_args = { "-Xmx512m" },
          incremental_build = true,
          disable_update_notifications = false,
          test_classname_patterns = {
            "^.*Tests?$",
            "^.*IT$",
            "^.*Spec$",
          },
        },
      },
    },
  },
}
-- return {
--   -- adiciona o adapter neotest-java como dependência
--   {
--     "rcasia/neotest-java",
--     ft = "java",
--     dependencies = {
--       "mfussenegger/nvim-jdtls", -- ou "nvim-java/nvim-java", dependendo do seu setup de LSP
--       "mfussenegger/nvim-dap", -- opcional, para debug
--     },
--   },
--
--   -- configura o neotest para usar o adapter
--   {
--     "nvim-neotest/neotest",
--     opts = function(_, opts)
--       opts.adapters = opts.adapters or {}
--       table.insert(
--         opts.adapters,
--         require("neotest-java")({
--           junit_jar = nil,
--           jvm_args = { "-Xmx512m" },
--           incremental_build = true,
--           disable_update_notifications = false,
--           test_classname_patterns = {
--             "^.*Tests?$",
--             "^.*IT$",
--             "^.*Spec$",
--           },
--         })
--       )
--     end,
--   },
-- }
