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

    -- TS/JS: tsgo (types) + oxlint (lint/fix) + oxfmt (format).
    -- Python: ty (types) + ruff (lint/fix/format).
    -- oxfmt keeps its shipped behavior (workspace_required: attaches only when
    -- it finds an oxfmt config — which this user always has).
    for _, s in ipairs({ "tsgo", "oxlint", "ruff", "ty", "oxfmt" }) do
      file_only(s)
    end
    vim.lsp.enable({ "tsgo", "oxlint", "ruff", "ty", "oxfmt" })

    -- Format + fix on save through the already-running servers (no per-save
    -- process spawn — replaces conform). Toggle with <leader>tf.
    local function is_formatter(client)
      return client.name == "oxfmt" or client.name == "ruff"
    end
    -- Apply one "source" code action (e.g. organize imports) from a client,
    -- synchronously, so its edits land before the buffer is written.
    local function apply_source_action(bufnr, client, kind)
      local params = {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
        context = { only = { kind }, diagnostics = {} },
      }
      local resp = client:request_sync("textDocument/codeAction", params, 2000, bufnr)
      for _, action in ipairs((resp or {}).result or {}) do
        if not action.edit and action.data then
          local r = client:request_sync("codeAction/resolve", action, 2000, bufnr)
          action = (r and r.result) or action
        end
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
        elseif action.command then
          client:exec_cmd(type(action.command) == "table" and action.command or action, { bufnr = bufnr })
        end
      end
    end

    local function fix_and_format(bufnr)
      -- 1) lint auto-fix / organize imports via each server.
      for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
        if client.name == "oxlint" then
          vim.lsp.buf_request_sync(bufnr, "workspace/executeCommand", {
            command = "oxc.fixAll",
            arguments = { { uri = vim.uri_from_bufnr(bufnr) } },
          }, 2000)
        elseif client.name == "ruff" then
          apply_source_action(bufnr, client, "source.organizeImports.ruff")
        end
      end
      -- 2) format via the formatter servers only (oxfmt for web, ruff for Python).
      vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 2000, filter = is_formatter })
    end

    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("lsp-format-on-save", { clear = true }),
      callback = function(args)
        if not vim.g.disable_autoformat then
          fix_and_format(args.buf)
        end
      end,
    })

    vim.keymap.set({ "n", "x" }, "<leader>cf", function()
      vim.lsp.buf.format({ filter = is_formatter })
    end, { desc = "Format buffer/selection" })
    vim.keymap.set("n", "<leader>tf", function()
      vim.g.disable_autoformat = not vim.g.disable_autoformat
      vim.notify("Fix/format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
    end, { desc = "Toggle fix/format on save" })

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
        -- Formatting (<leader>cf) + format-on-save are set up above via the LSP.
        map("<leader>fS", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", "Workspace symbols")

        -- oxlint ships a fix-all command; expose it manually. The fix-on-save
        -- (lint-then-format) is handled in plugins/format.lua.
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client.name == "oxlint" then
          map("<leader>cF", "<cmd>LspOxlintFixAll<CR>", "oxlint: fix all")
        end

        -- ty's semantic tokens repaint strings and override treesitter
        -- highlighting (incl. embedded SQL), so disable them — treesitter owns
        -- highlighting; ty still does type-checking/diagnostics/hover.
        if client and client.name == "ty" then
          client.server_capabilities.semanticTokensProvider = nil
        end
      end,
    })
  end,
}
