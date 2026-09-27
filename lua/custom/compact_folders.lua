-- ============================================================================
-- Compact folders for snacks.explorer (IntelliJ/VSCode style)
-- ============================================================================
--
-- Collapses chains of single-child directories into one row, e.g.
-- java/com/nicolai/ecommerce instead of four nested rows.
--
-- WHY THIS EXISTS
-- ----------------------------------------------------------------------------
-- snacks.nvim has no official support for this. It was requested in
-- https://github.com/folke/snacks.nvim/issues/916 and the maintainer replied
-- "Not interested in adding this". Everything below is built on INTERNAL,
-- UNDOCUMENTED snacks APIs, with no stability guarantee between versions.
--
-- If something breaks after a snacks.nvim update, first compare the overrides
-- here with the originals in:
--   lua/snacks/picker/format.lua          -> M.tree(item, picker), M.filename(item, picker)
--   lua/snacks/explorer/tree.lua          -> Tree:node(path), Node structure
--   lua/snacks/picker/source/explorer.lua -> how finder items are built
--                                            (fields: parent, last, open,
--                                            internal, file, dir)
--
-- ARCHITECTURE (independent intervention points)
-- ----------------------------------------------------------------------------
-- 1. `transform` (explorer source option): removes the "middle"/"tail" nodes
--    of a single-child chain from the LIST. They get no row of their own and
--    become part of the "head" row's text instead.
-- 2. `Format.tree` (monkeypatch): recomputes the indent skipping absorbed
--    ancestors. Otherwise the children of the chain's tail would be indented
--    N levels deep instead of 1 level below the compacted row.
-- 3. `Format.filename` (monkeypatch): replaces the head row's TEXT with the
--    compacted path ("java" -> "java/com/nicolai/ecommerce"), only while the
--    folder is open (node.open == true). Closed, it shows its own name.
-- 4. `add_compact` action: makes "a" create files inside the chain's real
--    tail directory instead of the head directory.
--
-- WHAT AN "ABSORBED" NODE IS
-- ----------------------------------------------------------------------------
-- A directory node is absorbed (gets no row of its own) when:
--   - it is a directory (node.dir == true)
--   - it has a parent (node.parent ~= nil)
--   - the parent is not the explorer root (node.parent.parent ~= nil). The
--     root is never rendered, so the first level of folders inside the cwd is
--     ALWAYS visible, even if there's only one.
--   - the parent has exactly 1 child (this node)
-- The check is local (only looks at the direct parent). It still works for
-- whole chains because `compact_chain` walks the full chain anyway.
--
-- FRAGILE ASSUMPTIONS (not guaranteed by the official docs)
-- ----------------------------------------------------------------------------
-- (a) `item.file` is the key used by `Tree:node(item.file)`. Not a documented
--     field.
-- (b) `node.children` is a table with arbitrary keys (iterated with `pairs`,
--     not `ipairs`). If it becomes a list, `pairs` still works.
-- (c) `node.path`, `node.parent`, `node.dir`, `node.last` and `node.open` are
--     fields observed in real usage, not in the official docs.
-- (d) In `Format.filename`, the segment holding the folder name is found by
--     comparing its TEXT (ignoring a trailing "/") with the node's basename,
--     not by highlight group, since it's unclear which group directories use
--     in tree mode. If snacks changes the returned text, the rename silently
--     stops happening (safe fallback: the original name is shown).
-- (e) `Format.tree` is SHARED by every source with `tree = true` (e.g.
--     lsp_symbols), hence the `picker.opts.source ~= "explorer"` guard.
-- (f) The patches are applied once, in `setup()`, to the
--     `snacks.picker.format` module. If another plugin overrides
--     `Format.tree` or `Format.filename` later, whichever runs last wins.
-- (g) `is_absorbed` and `compact_chain` call `vim.fn.fnamemodify` on every
--     row format. Not cached; may be noticeable on very large trees.
--
-- HOW TO TEST
-- ----------------------------------------------------------------------------
-- 1. Open a Java/Kotlin project with nested packages (e.g. com/foo/bar/baz
--    where every intermediate folder has a single child).
-- 2. A CLOSED folder shows only its own name (e.g. "java").
-- 3. An OPEN folder (<CR>, recursive_toggle) shows the compacted path
--    (e.g. "java/com/foo/bar/baz") and baz's children are indented 1 level
--    below that row, not N.
-- 4. Folders with 2+ children, or whose only child is a FILE, are never
--    compacted.
-- 5. Pressing "a" on a compacted row pre-fills the prompt with
--    "java/com/foo/bar/baz/" and creates the file inside "baz", not "java".
-- ============================================================================

local M = {}

local function child_count(node)
  local n = 0
  for _ in pairs(node.children or {}) do
    n = n + 1
    if n > 1 then
      break
    end
  end
  return n
end

local function get_children(node)
  local children = {}
  for _, c in pairs(node.children or {}) do
    children[#children + 1] = c
  end
  return children
end

local function basename(node)
  return vim.fn.fnamemodify(node.path, ":t")
end

-- See "WHAT AN ABSORBED NODE IS" above.
local function is_absorbed(node)
  local parent = node and node.parent
  if not (node and node.dir and parent and parent.parent) then
    return false
  end
  return child_count(parent) == 1
end

-- Walks down from `node` while each node has EXACTLY 1 child that is also a
-- directory. Returns the tail node (the real directory at the end of the
-- chain) and the list of basenames from head to tail. If `node` starts no
-- chain, returns `node` itself and a single-element list.
local function compact_chain(node)
  local tail = node
  local parts = { basename(node) }
  while true do
    local children = get_children(tail)
    if #children == 1 and children[1].dir then
      tail = children[1]
      parts[#parts + 1] = basename(tail)
    else
      break
    end
  end
  return tail, parts
end

-- Intervention point 1: hides absorbed nodes from the list.
-- `transform` runs per item; returning `false` removes the item, returning
-- nil keeps the default behavior. This runs BEFORE formatting, so the list
-- reaching Format.tree/Format.filename no longer contains these nodes.
function M.transform(item)
  if not item.dir then
    return
  end
  local Tree = require("snacks.explorer.tree")
  local node = Tree:node(item.file)
  if node and is_absorbed(node) then
    return false
  end
end

M.actions = {}

-- Opens the whole single-child chain at once on <CR>. Every absorbed node in
-- the chain is toggled internally (Tree:toggle on each), without getting a
-- row of its own thanks to `transform`.
function M.actions.recursive_toggle(picker, item)
  local Actions = require("snacks.explorer.actions")
  local Tree = require("snacks.explorer.tree")

  ---@param node snacks.picker.explorer.Node
  local function toggle_recursive(node)
    Tree:toggle(node.path)
    Actions.update(picker, { refresh = true })
    vim.schedule(function()
      local children = get_children(node)
      if #children == 1 and children[1].dir then
        toggle_recursive(children[1])
      end
    end)
  end

  local node = Tree:node(item.file)
  if not node then
    return
  end
  if node.dir then
    toggle_recursive(node)
  else
    picker:action("confirm")
  end
end

-- Intervention point 4: "a" (add file/directory) on a compacted row.
-- The native "explorer_add" creates the file inside the selected node's
-- directory, which on a compacted row is the chain's HEAD ("java"), not the
-- real directory ("ecommerce"). This action:
--   1. finds the node under the cursor (or its parent, if it's a file);
--   2. walks the single-child chain to find the real tail directory;
--   3. pre-fills the prompt with the compacted path + "/" for context;
--   4. strips that prefix from the answer (if left intact) and creates the
--      file/directory relative to the tail directory.
--
-- NOTE: this reimplements file creation (mkdir + io.open) instead of
-- decorating the native "explorer_add". It covers the common case (one file
-- or one directory) but doesn't replicate native details such as warning
-- about existing files or creating multiple files at once. An existing file
-- is not overwritten (append mode), just opened.
function M.actions.add_compact(picker, item)
  local Actions = require("snacks.explorer.actions")
  local Tree = require("snacks.explorer.tree")

  local node = item and Tree:node(item.file)
  if not node then
    return
  end
  -- on a file, use its parent directory (same as the native "explorer_add")
  local dir_node = node.dir and node or node.parent
  if not dir_node then
    return
  end

  local tail, parts = compact_chain(dir_node)

  -- only pre-fill when there's an actual chain; otherwise an empty prompt,
  -- like the native behavior
  local prefix = #parts > 1 and (table.concat(parts, "/") .. "/") or ""

  Snacks.input({
    prompt = 'Add a new file or directory (directories end with "/")',
    default = prefix,
  }, function(value)
    if not value or value == "" then
      return
    end
    if prefix ~= "" and value:sub(1, #prefix) == prefix then
      value = value:sub(#prefix + 1)
    end
    if value == "" then
      return
    end

    local is_dir = value:sub(-1) == "/"
    local target = vim.fs.normalize(tail.path .. "/" .. value)

    if is_dir then
      vim.fn.mkdir(target, "p")
    else
      vim.fn.mkdir(vim.fs.dirname(target), "p")
      local fd = io.open(target, "a")
      if fd then
        fd:close()
      end
    end

    Tree:open(tail.path)
    Actions.update(picker, { target = target, refresh = true })

    if not is_dir then
      vim.schedule(function()
        vim.cmd.edit(target)
      end)
    end
  end)
end

M.keys = {
  ["<CR>"] = "recursive_toggle",
  ["a"] = "add_compact",
}

-- Applies the Format monkeypatches. Must run AFTER `Snacks.setup()`, so
-- `snacks.picker.format` is loaded before we touch it.
function M.setup()
  local Format = require("snacks.picker.format")

  -- Intervention point 2: tree indent.
  -- Copy of the original `M.tree` (lua/snacks/picker/format.lua) with ONE
  -- change: absorbed ancestors get no icon/indent, since they have no row of
  -- their own.
  --
  -- FRAGILE: this is a manual copy, not a decorator (the traversal itself has
  -- to change). If the original changes its signature, highlight group
  -- ("SnacksPickerTree") or icons (picker.opts.icons.tree.{vertical,middle,
  -- last}), this copy will drift from the plugin.
  local tree_orig = Format.tree
  Format.tree = function(item, picker)
    if picker.opts.source ~= "explorer" then
      return tree_orig(item, picker)
    end
    local icons = picker.opts.icons.tree
    local indent = {}
    local node = item
    while node and node.parent do
      if node == item or not is_absorbed(node) then
        local icon
        if node ~= item then
          icon = node.last and " " or icons.vertical
        else
          icon = node.last and icons.last or icons.middle
        end
        table.insert(indent, 1, icon)
      end
      -- absorbed ancestors are skipped visually, but we keep walking up
      node = node.parent
    end
    return { { table.concat(indent), "SnacksPickerTree" } }
  end

  -- Intervention point 3: text of the chain's head row.
  -- Decorates the original: `filename_orig` builds the segments first (icon,
  -- git status colors, etc. stay intact), then only the TEXT of the segment
  -- holding the folder name is replaced. Compacts only while the folder is
  -- open; closed, showing the full path would be redundant.
  -- See fragile assumption (d) above.
  local filename_orig = Format.filename
  Format.filename = function(item, picker)
    local ret = filename_orig(item, picker)
    if picker.opts.source ~= "explorer" or not item.dir then
      return ret
    end
    local node = require("snacks.explorer.tree"):node(item.file)
    if not (node and node.open) then
      return ret
    end
    local _, parts = compact_chain(node)
    if #parts == 1 then
      return ret
    end
    local name, label = parts[1], table.concat(parts, "/")
    for _, seg in ipairs(ret) do
      if seg[1]:gsub("/$", "") == name then
        seg[1] = seg[1]:match("/$") and (label .. "/") or label
        break
      end
    end
    return ret
  end
end

return M
