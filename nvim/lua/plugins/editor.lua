-- Quality-of-life editor plugins.
return {
  -- Keybinding discovery popup.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "hunks" },
        { "<leader>d", group = "diagnostics" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>t", group = "toggle" },
        { "<leader>s", group = "session" },
      },
    },
  },

  -- Statusline.
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto", -- follows the active colorscheme (stock default here)
        globalstatus = true,
        section_separators = "",
        component_separators = "|",
      },
    },
  },

  -- Auto-insert matching brackets/quotes.
  {
    "echasnovski/mini.pairs",
    event = "InsertEnter",
    opts = {},
  },

  -- Add/change/delete surrounding pairs (parens, quotes, tags, ...).
  {
    "echasnovski/mini.surround",
    event = "VeryLazy",
    opts = {},
  },

  -- Layout-preserving buffer delete (raw :bdelete can close the window / quit).
  {
    "echasnovski/mini.bufremove",
    keys = {
      {
        "<leader>w",
        function()
          -- Save first (only if it's a normal, named, modified file), then close.
          if vim.bo.modified and vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
            vim.cmd("write")
          end
          require("mini.bufremove").delete(0, false)
        end,
        desc = "Save & close buffer",
      },
      { "<leader>W", function() require("mini.bufremove").delete(0, true) end, desc = "Delete buffer (force, discard changes)" },
    },
  },

  -- Highlight, list and jump between TODO / FIXME / NOTE comments.
  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = { signs = false },
  },
}
