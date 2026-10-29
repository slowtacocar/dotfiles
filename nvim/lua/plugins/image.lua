-- Inline Markdown images and previews when opening image files directly.
return {
  "3rd/image.nvim",
  lazy = false,
  build = false, -- use the ImageMagick CLI instead of building a Lua rock
  opts = {
    backend = "kitty",
    processor = "magick_cli",
    tmux_show_only_in_active_window = true,
  },
}
