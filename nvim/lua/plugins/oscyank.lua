-- Copy to the terminal's clipboard, including through SSH and tmux.
return {
  "ojroques/vim-oscyank",
  branch = "main",
  keys = {
    { "<leader>y", "<Plug>OSCYankOperator", mode = "n", desc = "Copy via OSC 52" },
    { "<leader>yy", "<leader>y_", mode = "n", remap = true, desc = "Copy line via OSC 52" },
    { "<leader>y", "<Plug>OSCYankVisual", mode = "x", desc = "Copy selection via OSC 52" },
  },
}
