-- File-explorer sidebar (replaces neo-tree). Inline git status markers + a
-- "changed files only" toggle. Opens files normally into buffers.
return {
  "nvim-tree/nvim-tree.lua",
  lazy = false, -- auto-opens on startup, so load it eagerly
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>n", "<cmd>NvimTreeToggle<cr>", desc = "Explorer: toggle" },
    { "<leader>E", "<cmd>NvimTreeFindFile<cr>", desc = "Explorer: reveal current file" },
    {
      "<leader>gc",
      function() require("nvim-tree.api").tree.toggle_git_clean_filter() end,
      desc = "Toggle changed-files-only",
    },
  },
  init = function()
    -- nvim-tree wants netrw disabled before it loads.
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    -- Auto-open the tree on startup (skip when reading piped stdin).
    vim.api.nvim_create_autocmd("StdinReadPre", {
      group = vim.api.nvim_create_augroup("nvimtree-autoopen", { clear = true }),
      callback = function() vim.g._nvimtree_stdin = true end,
    })
    vim.api.nvim_create_autocmd("VimEnter", {
      group = "nvimtree-autoopen",
      callback = function(data)
        if vim.g._nvimtree_stdin then return end
        local api = require("nvim-tree.api")
        if vim.fn.isdirectory(data.file) == 1 then
          vim.cmd.cd(data.file) -- `nvim <dir>`: root there, focus the tree
          api.tree.open()
        else
          -- `nvim` / `nvim file`: show the tree but keep the cursor in the editor.
          api.tree.open()
          vim.schedule(function()
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              if vim.bo[vim.api.nvim_win_get_buf(w)].ft ~= "NvimTree" then
                vim.api.nvim_set_current_win(w)
                return
              end
            end
          end)
        end
      end,
    })
  end,
  opts = {
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
    update_focused_file = { enable = true }, -- highlight the file you're editing
    hijack_directories = { enable = true }, -- `nvim .` opens the tree
    view = { width = 34, preserve_window_proportions = true },
    renderer = {
      group_empty = true,
      highlight_git = "name", -- tint changed file names
      icons = { show = { git = true } },
    },
    git = {
      enable = true,
      timeout = 1000, -- monorepo headroom (fsmonitor keeps `git status` fast)
    },
    filters = {
      dotfiles = false, -- show dotfiles
      git_ignored = false, -- show gitignored files (dirs are lazy-scanned, so cheap)
    },
    -- Keep the tree consistent across tabpages.
    tab = { sync = { open = true, close = true } },
    actions = {
      open_file = {
        quit_on_open = false,
        window_picker = { enable = false }, -- open in the editor window, no picker prompt
      },
    },
  },
}
