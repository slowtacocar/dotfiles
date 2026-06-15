-- Yank history: records everything you yank and lets you pick from it in a
-- Telescope picker (with full-text preview). Paste/replace the selected entry.
return {
  "AckslD/nvim-neoclip.lua",
  dependencies = { "nvim-telescope/telescope.nvim" },
  event = "VeryLazy", -- load early so it captures yanks from the start
  keys = {
    { "<leader>fy", "<cmd>Telescope neoclip<cr>", desc = "Yank history" },
  },
  opts = {
    history = 100, -- keep the last 100 yanks
    keys = {
      telescope = {
        i = { -- inside the picker:
          paste = "<c-p>", -- paste after cursor
          paste_behind = "<c-k>", -- paste before cursor
          select = "<cr>", -- set as the unnamed register (then paste with p)
        },
      },
    },
  },
  config = function(_, opts)
    require("neoclip").setup(opts)
    pcall(require("telescope").load_extension, "neoclip")
  end,
}
