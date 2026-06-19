-- Session persistence: auto-saves open buffers/splits/tabs per directory on
-- exit; restore them when you reopen nvim in that directory.
return {
  "folke/persistence.nvim",
  event = "VeryLazy",
  opts = {},
  init = function()
    -- Auto-restore the session for the cwd on a bare `nvim` launch.
    vim.api.nvim_create_autocmd("StdinReadPre", {
      group = vim.api.nvim_create_augroup("persistence-autoload", { clear = true }),
      callback = function() vim.g._persistence_stdin = true end,
    })
    vim.api.nvim_create_autocmd("VimEnter", {
      group = "persistence-autoload",
      nested = true, -- let restored buffers trigger filetype/LSP/treesitter
      callback = function()
        -- Skip if launched with a file/dir arg or reading piped stdin.
        if vim.g._persistence_stdin or vim.fn.argc() > 0 then return end
        require("persistence").load() -- no-op if no saved session for this dir
      end,
    })
  end,
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
