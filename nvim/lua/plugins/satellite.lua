-- Right-edge "overview ruler" (like VS Code): colored marks showing where
-- diagnostics, git changes, search hits, and marks are throughout the file.
return {
  "lewis6991/satellite.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    current_only = false,
    winblend = 20, -- more opaque so the bar is easy to see and click on
    excluded_filetypes = { "NvimTree", "TelescopePrompt", "lazy", "mason" },
    handlers = {
      cursor = { enable = true },
      search = { enable = true },
      diagnostic = {
        enable = true,
        min_severity = vim.diagnostic.severity.HINT,
      },
      gitsigns = { enable = true },
      marks = { enable = true },
      quickfix = { enable = true },
    },
  },
}
