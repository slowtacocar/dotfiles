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
    -- Debounce didChange notifications (default 150ms). Neovim triggers pull
    -- diagnostics off didChange, so this also throttles how often oxlint/tsgo
    -- re-lint while typing. NOTE: with multiple clients on a buffer the SMALLEST
    -- debounce wins, so this must be global ("*") to actually take effect.
    vim.lsp.config("*", {
      capabilities = capabilities,
      flags = { debounce_text_changes = 1000 },
    })

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

    -- dbt: the Fusion engine's language server, a subcommand of the CLI
    -- (`dbt lsp`, stdio) rather than a separate binary. lspconfig ships no
    -- definition for it, so declare it here.
    --
    -- Its root_dir is hand-rolled instead of going through file_only(): dbt
    -- projects are usually nested (adl/dbt/dbt_project.yml, not the repo root)
    -- and dbt_project.yml is the *only* sensible marker — there's no .git
    -- fallback like ruff/ty have. file_only()'s fallback would then start the
    -- server in the buffer's own directory for every stray .sql/.yaml on the
    -- machine, where it has no project to parse. So: no project, no server.
    -- --project-dir is REQUIRED, not a nicety: the server ignores rootUri and
    -- workspaceFolders entirely. Without it dbt.getProjectInfo returns {} and
    -- every request answers null, while still looking healthy in :LspInfo.
    -- cmd is a function so each project gets its own root on the command line.
    vim.lsp.config("dbt", {
      cmd = function(dispatchers, config)
        local cmd = { "dbt", "lsp", "--project-dir", config.root_dir }
        -- append "--lint-enabled", "true" for the SQL linter (off by default)
        return vim.lsp.rpc.start(cmd, dispatchers, { cwd = config.root_dir })
      end,
      filetypes = { "sql", "yaml" }, -- models and schema/source yml
      root_dir = function(bufnr, on_dir)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == "" or name:find("://", 1, true) then
          return -- not a real file (see file_only above)
        end
        local root = vim.fs.root(bufnr, "dbt_project.yml")
        if root then
          on_dir(root)
        end
      end,
    })

    vim.lsp.enable({ "tsgo", "oxlint", "ruff", "ty", "oxfmt", "dbt" })

    -- Format + fix on save through the already-running servers (no per-save
    -- process spawn — replaces conform). Toggle with <leader>tf.
    local function is_formatter(client)
      return client.name == "oxfmt" or client.name == "ruff"
    end

    -- Format on save via the already-running formatter servers (oxfmt for web,
    -- ruff for Python). Lint auto-fix / organize-imports is deliberately NOT run
    -- on save — it added noticeable latency; run it on demand instead
    -- (<leader>cF for oxlint fix-all, <leader>ca for a code action).
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("lsp-format-on-save", { clear = true }),
      callback = function(args)
        if not vim.g.disable_autoformat then
          vim.lsp.buf.format({ bufnr = args.buf, timeout_ms = 2000, filter = is_formatter })
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

        -- oxlint ships a fix-all command; expose it on demand (fix-on-save was
        -- removed for speed — saves now only format, see BufWritePre above).
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

        -- Highlight other references to the symbol under the cursor (like
        -- VSCode). CursorHold fires after 'updatetime' (250ms); moving clears.
        if client and client:supports_method("textDocument/documentHighlight") then
          local hl = vim.api.nvim_create_augroup("user-lsp-doc-highlight-" .. bufnr, { clear = true })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            group = hl,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            group = hl,
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
          })
          vim.api.nvim_create_autocmd("LspDetach", {
            group = hl,
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.clear_references()
              pcall(vim.api.nvim_del_augroup_by_id, hl)
            end,
          })
        end
      end,
    })
  end,
}
