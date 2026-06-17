-- General editor options.
local opt = vim.opt

-- Mouse support (requested): enable in all modes, right-click extends selection.
opt.mouse = "a"
opt.mousemodel = "extend"
opt.mousescroll = "ver:1,hor:6" -- mouse wheel scrolls 1 line at a time (default 3)

-- UI
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes" -- always show, avoids text shifting when diagnostics/git signs appear
opt.cursorline = true
opt.termguicolors = true -- 24-bit color (needed for modern highlights)
opt.scrolloff = 0 -- don't drag the cursor when scrolling (no forced edge margin)
opt.sidescrolloff = 8
opt.wrap = false
opt.splitright = true
opt.splitbelow = true
opt.showmode = false -- mode is shown in the statusline instead

-- Search
opt.ignorecase = false -- always case-sensitive search
opt.smartcase = false -- (no effect while ignorecase is off; kept explicit)
opt.hlsearch = true
opt.incsearch = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.breakindent = true

-- Files & undo
opt.undofile = true -- persistent undo across sessions
opt.swapfile = false
opt.confirm = true -- prompt to save instead of failing on :q with changes

-- System clipboard (yank/paste integrates with macOS pasteboard)
opt.clipboard = "unnamedplus"

-- Performance / UX
opt.updatetime = 250 -- faster CursorHold (git blame, diagnostics hover)
opt.timeoutlen = 400 -- which-key popup delay
opt.completeopt = "menu,menuone,noselect"

-- Show certain whitespace
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Live substitution preview
opt.inccommand = "split"
