-- GitHub Copilot — official Vimscript plugin (inline ghost-text suggestions).
return {
  "github/copilot.vim",
  event = "InsertEnter",
  init = function()
    -- blink.cmp owns <Tab>, so don't let Copilot grab it. Accept with <C-l>.
    vim.g.copilot_no_tab_map = true
  end,
  config = function()
    -- Accept the whole suggestion. expr+replace_keycodes per copilot.vim docs.
    -- <Right> accepts when a suggestion is showing, else moves the cursor right.
    vim.keymap.set("i", "<Right>", 'copilot#Accept("\\<Right>")', {
      expr = true,
      replace_keycodes = false,
      desc = "Copilot: accept suggestion (or move right)",
    })
    vim.keymap.set("i", "<C-l>", 'copilot#Accept("\\<CR>")', {
      expr = true,
      replace_keycodes = false,
      desc = "Copilot: accept suggestion",
    })
    -- Word/line-granular accept and cycling through suggestions.
    vim.keymap.set("i", "<C-j>", "<Plug>(copilot-accept-word)", { desc = "Copilot: accept word" })
    vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { desc = "Copilot: next suggestion" })
    vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { desc = "Copilot: prev suggestion" })
    vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)", { desc = "Copilot: dismiss" })

    -- Toggle Copilot for the current buffer.
    vim.keymap.set("n", "<leader>tc", "<cmd>Copilot toggle<CR>", { desc = "Toggle Copilot" })
  end,
}
