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

    local function diff_hl()
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
    end

    -- Re-apply the diff overrides whenever the colorscheme (re)loads.
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("diff-highlights", { clear = true }),
      callback = diff_hl,
    })
    vim.cmd.colorscheme("modus_vivendi")
  end,
}
