-- Session persistence: auto-saves open buffers/splits/tabs per directory on
-- exit; restore them when you reopen nvim in that directory.
return {
  "folke/persistence.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    { "<leader>Sr", function() require("persistence").load() end, desc = "Restore session (this dir)" },
    { "<leader>Sl", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
    { "<leader>Sx", function() require("persistence").stop() end, desc = "Stop saving this session" },
  },
  config = function(_, opts)
    require("persistence").setup(opts)
    -- Close the file tree before saving so it doesn't restore as a broken pane.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = function() pcall(vim.cmd, "NvimTreeClose") end,
    })
  end,
}
