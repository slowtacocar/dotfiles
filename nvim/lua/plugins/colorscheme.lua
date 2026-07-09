-- Colorscheme: Modus Vivendi — high-contrast with a true #000000 background.
-- Modus's only weak spot is its diffs (DiffAdd carries a fg that flattens
-- syntax, and DiffText == DiffChange so changed words don't pop), so we override
-- just the diff groups with the known-good values (Neovim's default palette).
return {
  "miikanissi/modus-themes.nvim",
  priority = 1000, -- load before other plugins so highlights are set first
  config = function()
    require("modus-themes").setup({
      style = "modus_vivendi", -- the dark, pure-black variant
      transparent = false,
      dim_inactive = false,
    })

    local function theme_overrides()
      -- Add/Change tint the background only (no fg) so syntax shows through.
      vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#0d3019" })
      vim.api.nvim_set_hl(0, "DiffChange", { bg = "#2a2110" })
      vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#3a1416" }) -- no fg, so deleted lines keep syntax
      -- The changed text (what inline:char paints): NO foreground, so syntax
      -- highlighting shows through — just a brighter bg than the diff line, so
      -- the changed region pops as a lighter patch of the same color.
      vim.api.nvim_set_hl(0, "DiffText", { bg = "#5c4512" }) -- vs DiffChange #2a2110
      vim.api.nvim_set_hl(0, "DiffTextAdd", { bg = "#1a6e38" }) -- vs DiffAdd #0d3019
      vim.api.nvim_set_hl(0, "DiffTextChange", { bg = "#5c4512" })
      vim.api.nvim_set_hl(0, "DiffTextDelete", { bg = "#6e2026" }) -- vs DiffDelete #3a1416

      -- LSP document-highlight (references to the symbol under the cursor, like
      -- VSCode): background only, so the symbol keeps its syntax color. Modus
      -- ships these with a fg that would flatten it.
      for _, g in ipairs({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }) do
        vim.api.nvim_set_hl(0, g, { bg = "#2d3f5e" })
      end
    end

    -- Re-apply the overrides whenever the colorscheme (re)loads.
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("theme-highlights", { clear = true }),
      callback = theme_overrides,
    })
    vim.cmd.colorscheme("modus_vivendi")
  end,
}
