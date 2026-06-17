-- Fuzzy finder: files, live grep, symbols, etc.
return {
  "nvim-telescope/telescope.nvim",
  branch = "master", -- 0.1.x is frozen; master has the nvim 0.11 deprecation fixes

  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Native fzf sorter for much faster matching (built with make).
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    -- Route vim.ui.select through Telescope (e.g. LSP code actions).
    "nvim-telescope/telescope-ui-select.nvim",
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Grep (live)" },
    -- Buffers in most-recently-used order (current excluded) — the "stack".
    {
      "<leader>fb",
      function()
        require("telescope.builtin").buffers({ sort_mru = true, ignore_current_buffer = true })
      end,
      desc = "Buffers (recent first)",
    },
    { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Find help" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    { "<leader>fw", "<cmd>Telescope grep_string<CR>", desc = "Grep word under cursor" },
    { "<leader>fd", "<cmd>Telescope diagnostics<CR>", desc = "Find diagnostics" },
    { "<leader>fs", "<cmd>Telescope lsp_document_symbols<CR>", desc = "Document symbols" },
    { "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search in buffer" },
    { "<leader><space>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
  },
  opts = function()
    local actions = require("telescope.actions")
    return {
      defaults = {
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
            ["<Esc>"] = actions.close, -- single Esc closes from insert
          },
        },
        path_display = { "truncate" },
      },
      pickers = {
        find_files = { hidden = true }, -- include dotfiles
      },
      extensions = {
        ["ui-select"] = {},
      },
    }
  end,
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    pcall(telescope.load_extension, "fzf")
    pcall(telescope.load_extension, "ui-select")
  end,
}
