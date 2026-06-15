-- General keymaps. Plugin-specific maps live in each plugin spec.
local map = vim.keymap.set

-- Clear search highlight with <Esc>
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Window navigation with <C-hjkl>
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Write all & quit everything.
map("n", "<leader>q", "<cmd>wqa<CR>", { desc = "Write all & quit" })

-- Close the left-most editor pane (never the file tree), no matter which pane
-- you're currently in.
map("n", "<leader>e", function()
  local leftmost, mincol
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local b = vim.api.nvim_win_get_buf(w)
    local floating = vim.api.nvim_win_get_config(w).relative ~= ""
    if not floating and vim.bo[b].ft ~= "NvimTree" then
      local col = vim.fn.win_screenpos(w)[2]
      if not mincol or col < mincol then
        mincol, leftmost = col, w
      end
    end
  end
  if leftmost then
    pcall(vim.api.nvim_win_close, leftmost, false)
  end
end, { desc = "Close left-most editor pane" })

-- Resize windows with arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Keep cursor centered when jumping / searching
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next search result (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centered)" })

-- Move selected lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Stay in indent mode when shifting in visual
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Buffers: cycling keys live in plugins/bufferline.lua (visual tab order) and
-- the layout-preserving delete keys live in plugins/editor.lua (mini.bufremove).

-- Diagnostics (LSP) quickfix navigation
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "<leader>de", vim.diagnostic.open_float, { desc = "Diagnostics: line detail" })
map("n", "<leader>dq", vim.diagnostic.setloclist, { desc = "Diagnostics: to loclist" })
