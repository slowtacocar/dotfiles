-- Syntax highlighting, indentation and incremental selection via tree-sitter.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdate", "TSInstall", "TSInstallInfo" },
  main = "nvim-treesitter.configs",
  opts = {
    ensure_installed = {
      "bash", "c", "css", "diff", "dockerfile", "git_config", "gitcommit",
      "gitignore", "html", "javascript", "jsdoc", "json", "jsonc", "lua",
      "luadoc", "markdown", "markdown_inline", "python", "query", "regex",
      "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
    },
    auto_install = true, -- install parsers for new filetypes on the fly
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = {
      enable = true,
      keymaps = {
        init_selection = "<C-space>",
        node_incremental = "<C-space>",
        node_decremental = "<bs>",
      },
    },
  },
}
