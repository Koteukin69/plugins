local M = {}

local state = {
  autocmds_created = false,
  buf = nil,
  layout = "--",
  monitor_job = nil,
  running = false,
  setup_done = false,
  win = nil,
}

local config = {
  highlight = "NormalFloat",
  padding = " ",
  winblend = 0,
  zindex = 50,
}

local query_script = [[
for qdbus in qdbus6 qdbus; do
  command -v "$qdbus" >/dev/null 2>&1 || continue

  index=$("$qdbus" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || "$qdbus" org.kde.keyboard /Layouts getLayout 2>/dev/null)
  layouts=$("$qdbus" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || "$qdbus" --literal org.kde.keyboard /Layouts getLayoutsList 2>/dev/null)

  if [ -n "$index" ] && [ -n "$layouts" ]; then
    printf 'kde_index=%s\n' "$index"
    printf 'kde_layouts=%s\n' "$layouts"
    exit 0
  fi

  "$qdbus" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getCurrentLayout 2>/dev/null && exit 0
  "$qdbus" org.kde.keyboard /Layouts getCurrentLayout 2>/dev/null && exit 0
done

if command -v fcitx5-remote >/dev/null 2>&1; then
  fcitx5-remote -n 2>/dev/null && exit 0
fi

if command -v ibus >/dev/null 2>&1; then
  ibus engine 2>/dev/null && exit 0
fi

if command -v xkblayout-state >/dev/null 2>&1; then
  xkblayout-state print %s 2>/dev/null && exit 0
fi
]]

local monitor_script = [[
if command -v dbus-monitor >/dev/null 2>&1; then
  exec dbus-monitor --session "type='signal',interface='org.kde.KeyboardLayouts',member='layoutChanged'" 2>/dev/null
fi
]]

local function parse_kde_layout(value)
  local index = tonumber(value:match("kde_index=(%d+)"))
  if not index then
    return nil
  end

  local layouts = {}
  for code in value:gmatch('%(sss%)%s+"([^"]+)"') do
    layouts[#layouts + 1] = code
  end

  return layouts[index + 1]
end

local function trim(value)
  return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalize(value)
  local raw = value or ""
  local normalized = trim((parse_kde_layout(raw) or raw):lower()):gsub("[\"'(),]", "")

  if normalized == "" then
    return nil
  end

  if normalized:match("ru") or normalized:match("russian") then
    return "ru"
  end

  if normalized:match("us") or normalized:match("en") or normalized:match("english") then
    return "en"
  end

  return normalized:match("^[%a_%-]+") or normalized
end

local function valid_buf()
  return state.buf and vim.api.nvim_buf_is_valid(state.buf)
end

local function valid_win()
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function ensure_buf()
  if valid_buf() then
    return state.buf
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].swapfile = false

  return state.buf
end

local function window_config(text)
  local width = math.max(1, vim.fn.strdisplaywidth(text))

  return {
    anchor = "SE",
    col = math.max(1, vim.o.columns),
    focusable = false,
    height = 1,
    noautocmd = true,
    relative = "editor",
    row = math.max(1, vim.o.lines - vim.o.cmdheight),
    style = "minimal",
    width = width,
    zindex = config.zindex,
  }
end

local function render()
  local text = config.padding .. state.layout .. config.padding
  local buf = ensure_buf()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.bo[buf].modifiable = false

  if valid_win() then
    vim.api.nvim_win_set_config(state.win, window_config(text))
  else
    state.win = vim.api.nvim_open_win(buf, false, window_config(text))
    vim.wo[state.win].winblend = config.winblend
    vim.wo[state.win].winhighlight = "Normal:" .. config.highlight
  end
end

function M.update()
  if state.running then
    return
  end

  state.running = true

  local output = {}
  local job = vim.fn.jobstart({ "sh", "-c", query_script }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      output = data or {}
    end,
    on_exit = function()
      state.running = false

      local next_layout = normalize(table.concat(output, " "))
      if not next_layout or next_layout == state.layout then
        return
      end

      state.layout = next_layout
      vim.schedule(render)
    end,
  })

  if job <= 0 then
    state.running = false
  end
end

function M.start_monitor()
  if state.monitor_job then
    return state.monitor_job
  end

  local job = vim.fn.jobstart({ "sh", "-c", monitor_script }, {
    stdout_buffered = false,
    on_stdout = function(_, data)
      if not data then
        return
      end

      for _, line in ipairs(data) do
        if line:match("layoutChanged") or line:match("uint32") then
          M.update()
          return
        end
      end
    end,
    on_exit = function()
      state.monitor_job = nil
    end,
  })

  if job <= 0 then
    return nil
  end

  state.monitor_job = job
  return job
end

function M.stop_monitor()
  if not state.monitor_job then
    return
  end

  vim.fn.jobstop(state.monitor_job)
  state.monitor_job = nil
end

local function create_autocmds()
  if state.autocmds_created then
    return
  end

  state.autocmds_created = true

  local group = vim.api.nvim_create_augroup("LangNvim", { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "FocusGained", "ModeChanged" }, {
    group = group,
    callback = function()
      M.update()
    end,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      render()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.stop_monitor()
    end,
  })
end

function M.setup(opts)
  if opts then
    config = vim.tbl_deep_extend("force", config, opts)
  end

  if state.setup_done then
    render()
    return
  end

  state.setup_done = true
  create_autocmds()
  render()
  M.update()
  M.start_monitor()
end

function M.component()
  return state.layout
end

function M.get_layout()
  return state.layout
end

return M
