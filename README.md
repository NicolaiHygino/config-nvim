# config-nvim

My Neovim configuration, built on [LazyVim](https://github.com/LazyVim/LazyVim)
and tuned mostly for Java development.

## Key features

### Java

- **Run the current file** in a terminal docked at the bottom, with or without
  arguments. It uses the JDK's source launcher (`java Main.java`), so there's no
  build step, and the other sources of the file's package tree are compiled too.
  The output stays open and navigable after the program exits.
- **Loose files work on their own.** A file outside a Maven/Gradle/Ant project
  gets its own jdtls root at its folder, so each one has its own classpath and
  the debugger runs next to it.
- **The explorer and pickers keep the project root.** They still root at the
  nearest build wrapper or git repo, even for those loose files.
- **The debugger UI stays open** after the program exits, so its console output
  isn't lost. Close it with `<leader>du`.
- **Tests** through [neotest-java](https://github.com/rcasia/neotest-java)
  (`*Test`, `*Tests`, `*IT` and `*Spec` classes).
- Signature help from jdtls, 4-space indentation, and no jdtls progress spam
  ("Building", "Validate documents") in the notifications.

### Explorer

- **Compact folders** in the snacks explorer, IntelliJ/VS Code style: an open
  chain of single-child folders shows as one row, e.g.
  `java/com/nicolai/ecommerce`. Pressing `a` on that row creates the file in
  the deepest folder. snacks.nvim doesn't support this, so it's built on its
  internal APIs in [`lua/custom/compact_folders.lua`](lua/custom/compact_folders.lua),
  which documents how it works and what may break on a snacks update.
- Hidden and git-ignored files are shown in the explorer and file pickers.
- The explorer is 30 columns wide.

### Editing

- **Completion** with blink.cmp: nothing is preselected or inserted until you
  accept it. `<Tab>`/`<S-Tab>` move through the list, `<CR>` accepts and
  `<C-Space>` opens the menu or toggles its documentation. Signature help shows
  automatically.
- **Scroll past the end of the file**, like VS Code: `scrolloff = 8` keeps
  8 lines of padding below the last line too.
- `q` closes the current buffer.
- Markdown is linted and formatted with a global markdownlint config at
  `~/.config/markdownlint/.markdownlint-cli2.yaml` (used to turn off the
  line-length rule).

### UI

- Tokyo Night with a transparent background, including sidebars and floats.

## Keymaps

These are the keymaps added on top of LazyVim's
[defaults](https://www.lazyvim.org/keymaps).

| Keys                | Where           | Action                                                |
| ------------------- | --------------- | ----------------------------------------------------- |
| `<leader>rr`        | Java buffers    | Run the current file                                  |
| `<leader>ra`        | Java buffers    | Run it with arguments (remembers the last ones)       |
| `q`                 | Normal mode     | Close the current buffer                              |
| `<Tab>` / `<S-Tab>` | Completion menu | Next / previous item                                  |
| `<CR>`              | Completion menu | Accept the selected item                              |
| `<C-Space>`         | Insert mode     | Show completion / toggle docs                         |
| `a`                 | Explorer        | New file (inside a compacted folder's deepest folder) |

In the run terminal, `q` hides it and `i` types into a program that's still
running.

## LazyVim extras

Enabled in [`lazyvim.json`](lazyvim.json):

- **Languages:** Java, Python, SQL, JSON, Docker, Tailwind
- **Debugging and testing:** `dap.core`, `test.core`
- **Editor and coding:** Telescope, LuaSnip, Yanky
- **Utilities:** REST client, mini.hipatterns, neoconf
- **AI:** claudecode

## Requirements

- Neovim 0.11+
- Git, plus the usual LazyVim requirements (a Nerd Font, a C compiler for
  Treesitter, ripgrep and fd)
- JDK 22+ to run multi-file programs with `<leader>rr` (JDK 11+ for single
  files)
- [`markdownlint-cli2`](https://github.com/DavidAnson/markdownlint-cli2) and
  the global config above, for Markdown linting

## Installation

Back up your current config, then clone this one:

```sh
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/NicolaiHygino/config-nvim ~/.config/nvim
nvim
```

lazy.nvim installs itself and every plugin on the first start. Mason installs
the language servers, including jdtls, when you open a file that needs them.

## Layout

```text
init.lua                  entry point, loads lua/config/lazy.lua
lazyvim.json              enabled LazyVim extras
lua/config/
  options.lua             scrolloff, root detection
  keymaps.lua             global keymaps
  autocmds.lua            Java settings and run keymaps, scroll past EOF
  lazy.lua                lazy.nvim bootstrap
lua/plugins/              plugin specs and overrides (one file per plugin)
lua/custom/
  compact_folders.lua     compact folders for the snacks explorer
```
