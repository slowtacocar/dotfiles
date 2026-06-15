-- On save: run oxlint's auto-fix FIRST, then format with oxfmt. Both live in a
-- single BufWritePre handler so the order is deterministic (two separate
-- autocmds would race, and conform was winning — formatting before the fix).
return {
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
      mode = { "n", "v" },
      desc = "Format buffer/selection",
    },
    {
      "<leader>tf",
      function()
        vim.g.disable_autoformat = not vim.g.disable_autoformat
        vim.notify("Fix/format on save: " .. (vim.g.disable_autoformat and "OFF" or "ON"))
      end,
      desc = "Toggle fix/format on save",
    },
  },
  init = function()
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = vim.api.nvim_create_augroup("fix-then-format-on-save", { clear = true }),
      callback = function(args)
        if vim.g.disable_autoformat then
          return -- toggled off via <leader>tf
        end
        local bufnr = args.buf

        -- 1) oxlint auto-fix. Synchronous so its workspace/applyEdit lands
        --    before we format and before the buffer is written.
        if next(vim.lsp.get_clients({ bufnr = bufnr, name = "oxlint" })) then
          vim.lsp.buf_request_sync(bufnr, "workspace/executeCommand", {
            command = "oxc.fixAll",
            arguments = { { uri = vim.uri_from_bufnr(bufnr) } },
          }, 2000)
        end

        -- 2) then format (requires conform, which lazy-loads it on demand).
        require("conform").format({ bufnr = bufnr, timeout_ms = 2000, lsp_format = "fallback" })
      end,
    })
  end,
  opts = function()
    return {
      -- oxfmt handles JS/TS/JSX/TSX, JSON, YAML, CSS, HTML, GraphQL, Markdown...
      formatters_by_ft = {
        javascript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescript = { "oxfmt" },
        typescriptreact = { "oxfmt" },
        json = { "oxfmt" },
        jsonc = { "oxfmt" },
        css = { "oxfmt" },
        scss = { "oxfmt" },
        less = { "oxfmt" },
        html = { "oxfmt" },
        yaml = { "oxfmt" },
        graphql = { "oxfmt" },
        markdown = { "oxfmt" },
      },
      -- Define the oxfmt formatter (not yet a conform built-in): pipe via stdin.
      formatters = {
        oxfmt = {
          command = "oxfmt",
          args = { "--stdin-filepath", "$FILENAME" },
          stdin = true,
          cwd = require("conform.util").root_file({ "package.json", ".git" }),
        },
      },
    }
  end,
}
