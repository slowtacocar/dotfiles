-- Sticky scroll: pin the enclosing function/scope to the top of the window
-- (like VS Code's sticky scroll), using tree-sitter.
return {
  "nvim-treesitter/nvim-treesitter-context",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  event = { "BufReadPost", "BufNewFile" },
  keys = {
    -- Jump up to the context line (e.g. the function signature).
    { "[c", function() require("treesitter-context").go_to_context(vim.v.count1) end, desc = "Jump to context" },
  },
  opts = {
    max_lines = 3, -- cap how many context lines are pinned
    multiline_threshold = 1, -- collapse multi-line signatures to a single line
    trim_scope = "outer", -- if over max_lines, drop the outermost scopes
    mode = "cursor", -- show the context of the scope the cursor is in
    separator = "─", -- subtle underline under the sticky context
  },
}
