-- VS Code-style tab bar of open buffers across the top.
return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = { "nvim-tree/nvim-web-devicons", "echasnovski/mini.bufremove" },
  event = "VeryLazy",
  keys = {
    -- Cycle in visual (tab) order.
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
    { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
    { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
    -- Reorder the current buffer.
    { "<S-Right>", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer right" },
    { "<S-Left>", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer left" },
    -- Manage.
    { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "Pin/unpin buffer" },
    { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other buffers" },
    { "<leader>br", "<cmd>BufferLineCloseRight<cr>", desc = "Close buffers to the right" },
    { "<leader>bl", "<cmd>BufferLineCloseLeft<cr>", desc = "Close buffers to the left" },
    -- Jump straight to a tab by position.
    { "<leader>1", "<cmd>BufferLineGoToBuffer 1<cr>", desc = "Go to buffer 1" },
    { "<leader>2", "<cmd>BufferLineGoToBuffer 2<cr>", desc = "Go to buffer 2" },
    { "<leader>3", "<cmd>BufferLineGoToBuffer 3<cr>", desc = "Go to buffer 3" },
    { "<leader>4", "<cmd>BufferLineGoToBuffer 4<cr>", desc = "Go to buffer 4" },
    { "<leader>5", "<cmd>BufferLineGoToBuffer 5<cr>", desc = "Go to buffer 5" },
  },
  opts = {
    options = {
      mode = "buffers",
      -- Layout-preserving close so clicking ✕ never collapses the window/editor.
      close_command = function(n) require("mini.bufremove").delete(n, false) end,
      right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,
      diagnostics = "nvim_lsp", -- show LSP errors/warnings on each tab
      diagnostics_indicator = function(_, _, diagnostics_dict)
        local s = ""
        for severity, n in pairs(diagnostics_dict) do
          local sym = (severity == "error") and " " or (severity == "warning") and " " or " "
          s = s .. sym .. n
        end
        return s
      end,
      -- Make room for the nvim-tree sidebar instead of overlapping it.
      offsets = {
        {
          filetype = "NvimTree",
          text = "File Explorer",
          text_align = "left",
          separator = true,
        },
      },
      show_buffer_close_icons = true,
      show_close_icon = false,
      separator_style = "thin",
      always_show_bufferline = true,
    },
  },
}
