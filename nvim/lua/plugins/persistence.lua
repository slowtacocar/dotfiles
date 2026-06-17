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
    -- Sessions don't store the nvim-tree window (mksession drops it), so a
    -- restore replaces the layout with one that has no tree. Reopen it after a
    -- session loads, keeping focus in the editor.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceLoadPost",
      callback = function()
        vim.schedule(function()
          local ok, api = pcall(require, "nvim-tree.api")
          if not ok then return end
          api.tree.open()
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(w)].ft ~= "NvimTree" then
              vim.api.nvim_set_current_win(w)
              return
            end
          end
        end)
      end,
    })
  end,
}
