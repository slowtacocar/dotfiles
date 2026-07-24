-- Syntax highlighting + indentation via tree-sitter.
--
-- nvim-treesitter's `main` branch (required for Neovim 0.12+; the frozen
-- `master` branch's query predicates crash on 0.12 and broke TS indent).
-- The main branch has no module system: parsers install via install(), Neovim
-- core does highlighting (vim.treesitter.start), and the plugin gives indentexpr.
-- Needs the `tree-sitter` CLI to build parsers (brew install tree-sitter-cli).
local ensure = {
  "bash", "c", "css", "diff", "dockerfile", "git_config", "gitcommit",
  "gitignore", "glimmer", "html", "javascript", "jsdoc", "json",
  "lua", "luadoc", "markdown", "markdown_inline", "python", "query", "regex",
  "sql", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false, -- the main branch does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(ensure)
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        if pcall(vim.treesitter.start, ev.buf) then
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
