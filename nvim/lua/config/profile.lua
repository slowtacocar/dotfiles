local M = {}
local active
local function now() return vim.uv.hrtime() / 1e6 end

function M.stop()
  if not active then return end
  local state = active
  active = nil
  state.timer:stop()
  state.timer:close()
  vim.api.nvim_del_augroup_by_id(state.group)
  if state.profiler then state.profiler.stop() end
  state.report.duration_ms = now() - state.started
  for key, started in pairs(state.pending) do
    state.report.unfinished[key] = now() - started
  end
  vim.fn.writefile({ vim.json.encode(state.report) }, state.path .. "/traffic.json")
  vim.notify("Profile saved: " .. state.path)
  return state.path
end

function M.start(seconds)
  if active then return active.path end
  seconds = seconds or 30
  assert(seconds >= 1 and seconds <= 120, "Profile duration must be 1–120 seconds")
  local path = vim.fn.stdpath("state") .. "/profiles/" .. os.date("%Y%m%d-%H%M%S") .. "-" .. vim.fn.getpid()
  vim.fn.mkdir(path, "p")
  local state = {
    path = path, started = now(), pending = {},
    group = vim.api.nvim_create_augroup("user-performance-profile", { clear = true }),
    timer = vim.uv.new_timer(),
    report = { requests = {}, notifications = {}, unfinished = {}, initial_requests = {},
      events = {}, loop_lag_ms = {}, clients = {} },
  }
  active = state
  local function client_name(id)
    local client = vim.lsp.get_client_by_id(id)
    return client and client.name or tostring(id)
  end
  for _, client in ipairs(vim.lsp.get_clients()) do
    state.report.clients[#state.report.clients + 1] = {
      id = client.id, name = client.name, root = client.config.root_dir,
      debounce = client.flags.debounce_text_changes,
    }
    for id, request in pairs(client.requests) do
      state.report.initial_requests[#state.report.initial_requests + 1] = {
        client = client.name, id = id, method = request.method, status = request.type,
      }
    end
  end
  vim.api.nvim_create_autocmd("LspRequest", {
    group = state.group,
    callback = function(ev)
      local data, request = ev.data, ev.data.request
      local method = client_name(data.client_id) .. " " .. request.method
      local key = data.client_id .. ":" .. data.request_id .. " " .. method
      local stats = state.report.requests[method] or { sent = 0, completed = 0, cancelled = 0, latency_ms = {} }
      state.report.requests[method] = stats
      if request.type == "pending" then
        stats.sent = stats.sent + 1
        state.pending[key] = now()
      elseif request.type == "cancel" then
        stats.cancelled = stats.cancelled + 1
      elseif request.type == "complete" then
        stats.completed = stats.completed + 1
        if state.pending[key] then
          stats.latency_ms[#stats.latency_ms + 1] = now() - state.pending[key]
          state.pending[key] = nil
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("LspNotify", {
    group = state.group,
    callback = function(ev)
      local key = client_name(ev.data.client_id) .. " " .. ev.data.method
      state.report.notifications[key] = (state.report.notifications[key] or 0) + 1
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertCharPre", "TextChangedI", "TextChanged", "CursorMovedI" }, {
    group = state.group,
    callback = function(ev)
      state.report.events[ev.event] = (state.report.events[ev.event] or 0) + 1
    end,
  })
  local previous = now()
  state.timer:start(100, 100, vim.schedule_wrap(function()
    if active ~= state then return end
    local current = now()
    state.report.loop_lag_ms[#state.report.loop_lag_ms + 1] = math.max(0, current - previous - 100)
    previous = current
    if current - state.started >= seconds * 1000 then M.stop() end
  end))
  local ok, profiler = pcall(require, "jit.p")
  if ok then
    profiler.start("vFsi10", path .. "/lua-profile.txt")
    state.profiler = profiler
  end
  vim.notify("Profiling for " .. seconds .. "s: reproduce the slowdown now")
  return path
end

function M.setup()
  vim.api.nvim_create_user_command("LspProfileStart", function(args)
    M.start(tonumber(args.args) or 30)
  end, { nargs = "?", desc = "Profile LSP traffic, Lua, and editor stalls (default 30s)" })
  vim.api.nvim_create_user_command("LspProfileStop", M.stop, { desc = "Stop profiling and save results" })
end

return M
