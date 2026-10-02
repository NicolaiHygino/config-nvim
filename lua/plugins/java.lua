return {
  {
    "mfussenegger/nvim-jdtls",
    opts = {
      -- Explicitly tell LazyVim's Java extra to load the test bundles
      test = false,
      -- Real projects root at their build file; loose single-file programs
      -- root at their own folder instead of the enclosing git repo, so each
      -- one gets its own classpath and the debugger's cwd is next to the file.
      root_dir = function(path)
        local root = vim.fs.root(path, {
          "mvnw",
          "gradlew",
          "settings.gradle",
          "settings.gradle.kts",
          "pom.xml",
          "build.gradle",
          "build.gradle.kts",
          "build.xml",
        })
        if root then
          return root
        end
        -- Only fall back for real files: unnamed preview buffers and jdt:// URIs
        -- would otherwise produce roots like "." that jdtls rejects.
        if path ~= "" and vim.uv.fs_stat(path) then
          return vim.fs.dirname(vim.fs.abspath(path))
        end
      end,
      settings = {
        java = {
          -- jdtls doesn't advertise signatureHelp unless this is enabled
          signatureHelp = { enabled = true },
        },
      },
    },
  },
}
