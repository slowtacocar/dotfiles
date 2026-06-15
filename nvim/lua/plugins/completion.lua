-- Completion engine: blink.cmp (fast, batteries-included).
return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "1.*", -- uses a prebuilt fuzzy-matching binary; no Rust toolchain needed
  dependencies = {
    "rafamadriz/friendly-snippets", -- a bank of common snippets
  },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      preset = "default", -- keeps <C-space> open, <C-e> hide, <C-n>/<C-p> select
      -- Arrow keys move through the options.
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      -- Tab accepts the highlighted option (or jumps a snippet placeholder).
      ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
      -- Enter always inserts a newline, never accepts.
      ["<CR>"] = { "fallback" },
    },
    appearance = {
      nerd_font_variant = "mono",
    },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      menu = { draw = { treesitter = { "lsp" } } },
    },
    signature = { enabled = true },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
