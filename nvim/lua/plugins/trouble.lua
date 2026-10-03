-- Persistent results panel: send a Telescope picker (grep, diagnostics, refs)
-- here and the list stays open in a side split while you work through it, with
-- the current item highlighted and previewed in the main window.
return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    focus = true, -- jump into the panel when it opens
    -- Right-hand sidebar. Swap to position = "bottom", size = 0.3 if long grep
    -- lines feel cramped in a narrow column.
    win = { type = "split", position = "right", size = 0.35 },
    -- Moving in the panel previews the hit in the main editor window; <CR>
    -- commits to it.
    preview = { type = "main", scratch = true },
  },
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics (workspace)" },
    { "<leader>xd", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Diagnostics (this buffer)" },
    { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
    { "<leader>xl", "<cmd>Trouble loclist toggle<CR>", desc = "Location list" },
    { "<leader>xs", "<cmd>Trouble symbols toggle<CR>", desc = "Symbols outline" },
    { "<leader>xr", "<cmd>Trouble lsp toggle<CR>", desc = "LSP references/definitions" },
    { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "TODO comments" },
    -- Step through the open list without leaving the file you're editing.
    {
      "]x",
      function() require("trouble").next({ skip_groups = true, jump = true }) end,
      desc = "Next trouble item",
    },
    {
      "[x",
      function() require("trouble").prev({ skip_groups = true, jump = true }) end,
      desc = "Previous trouble item",
    },
  },
}
