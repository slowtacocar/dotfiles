-- Language servers via Neovim's native LSP (nvim 0.11+ vim.lsp.config/enable).
-- nvim-lspconfig is used only for the server *definitions* it ships in lsp/*.lua
-- (tsgo, oxlint, ...); we activate them with vim.lsp.enable().
return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "saghen/blink.cmp" },
  config = function()
    -- Give every server blink.cmp's completion capabilities, and pin the
    -- position encoding so tsgo and oxlint agree (otherwise position requests
    -- like gd/hover warn about "multiple different client offset_encodings").
    local capabilities = require("blink.cmp").get_lsp_capabilities()
    capabilities.offsetEncoding = { "utf-16" }
    vim.lsp.config("*", { capabilities = capabilities })

    -- Don't let servers attach to non-file buffers (e.g. diffview's
    -- `diffview://` revision buffers) — they have no valid workspace path and
    -- crash the server with "workspace URI is not a valid file path: file://.".
    -- We wrap each server's root_dir: bail on URI buffers, otherwise delegate
    -- to the server's shipped root detection.
    local function file_only(server)
      local cfg = vim.lsp.config[server] or {}
      local orig_root_dir = cfg.root_dir
      local markers = cfg.root_markers
      vim.lsp.config(server, {
        root_dir = function(bufnr, on_dir)
          local name = vim.api.nvim_buf_get_name(bufnr)
          if name == "" or name:find("://", 1, true) then
            return -- not a real file; don't start the server here
          end
          if type(orig_root_dir) == "function" then
            return orig_root_dir(bufnr, on_dir) -- keep shipped logic for files
          end
          on_dir((markers and vim.fs.root(bufnr, markers)) or vim.fs.dirname(name))
        end,
      })
    end

    -- TS/JS: tsgo (types) + oxlint (lint/fix). Python: ty (types) + ruff (lint/fix).
    local servers = { "tsgo", "oxlint", "ruff", "ty" }
    for _, s in ipairs(servers) do
      file_only(s)
    end
    vim.lsp.enable(servers)

    -- Diagnostics presentation.
    vim.diagnostic.config({
      virtual_text = { spacing = 2, prefix = "●" },
      severity_sort = true,
      float = { border = "rounded", source = true },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.HINT] = "",
          [vim.diagnostic.severity.INFO] = "",
        },
      },
    })

    -- Buffer-local keymaps once a server attaches.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("user-lsp-attach", { clear = true }),
      callback = function(args)
        local bufnr = args.buf
        local function map(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = "LSP: " .. desc })
        end

        map("gd", "<cmd>Telescope lsp_definitions<CR>", "Go to definition")
        map("gr", "<cmd>Telescope lsp_references<CR>", "References")
        map("gI", "<cmd>Telescope lsp_implementations<CR>", "Go to implementation")
        map("gy", "<cmd>Telescope lsp_type_definitions<CR>", "Type definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("K", vim.lsp.buf.hover, "Hover docs")
        map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("<leader>lr", "<cmd>LspRestart<CR>", "Restart LSP (clears stale diagnostics)")
        map("<leader>li", "<cmd>LspInfo<CR>", "LSP info (attached clients)")
        -- Formatting is handled by conform.nvim (oxfmt) — see plugins/format.lua.
        map("<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", "Workspace symbols")

        -- oxlint ships a fix-all command; expose it manually. The fix-on-save
        -- (lint-then-format) is handled in plugins/format.lua.
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "oxlint" then
          map("<leader>cF", "<cmd>LspOxlintFixAll<CR>", "oxlint: fix all")
        end
      end,
    })
  end,
}
