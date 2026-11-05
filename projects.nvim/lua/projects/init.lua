local M = {}

local config = {
  file = vim.fn.stdpath("data") .. "/projects.json",
  nvim_tree = true,
}

local function normalize_path(path)
  path = vim.fn.fnamemodify(vim.fn.expand(path and path ~= "" and path or vim.fn.getcwd()), ":p")
  return path:gsub("/$", "")
end

local function read_projects()
  if vim.fn.filereadable(config.file) == 0 then
    return {}
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(config.file), "\n"))

  if not ok or type(decoded) ~= "table" then
    return {}
  end

  return decoded
end

local function write_projects(projects)
  vim.fn.mkdir(vim.fn.fnamemodify(config.file, ":h"), "p")
  vim.fn.writefile(vim.split(vim.json.encode(projects), "\n"), config.file)
end

function M.list()
  return read_projects()
end

function M.add(path)
  path = normalize_path(path)

  if vim.fn.isdirectory(path) == 0 then
    vim.notify("Project path is not a directory: " .. path, vim.log.levels.ERROR)
    return
  end

  local next_projects = { path }

  for _, project in ipairs(read_projects()) do
    if project ~= path then
      table.insert(next_projects, project)
    end
  end

  write_projects(next_projects)
  vim.notify("Project added: " .. path)
end

function M.remove_project(path)
  path = normalize_path(path)

  local next_projects = {}
  local removed = false

  for _, project in ipairs(read_projects()) do
    if project == path then
      removed = true
    else
      table.insert(next_projects, project)
    end
  end

  if not removed then
    vim.notify("Project not found: " .. path, vim.log.levels.WARN)
    return
  end

  write_projects(next_projects)
  vim.notify("Project removed: " .. path)
end

function M.open_project(path)
  path = normalize_path(path)

  if vim.fn.isdirectory(path) == 0 then
    vim.notify("Project path is not a directory: " .. path, vim.log.levels.ERROR)
    return
  end

  vim.cmd("cd " .. vim.fn.fnameescape(path))

  if config.nvim_tree then
    pcall(function()
      local api = require("nvim-tree.api")
      api.tree.change_root(path)
      api.tree.open()
    end)
  end

  vim.notify("Project opened: " .. path)
end

local function load_telescope()
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.load({ plugins = { "telescope.nvim" } })
  end

  local ok_telescope, pickers = pcall(require, "telescope.pickers")
  if not ok_telescope then
    vim.notify("projects.nvim requires telescope.nvim", vim.log.levels.ERROR)
    return
  end

  return pickers
end

local function select_project(projects)
  local pickers = load_telescope()
  if not pickers then
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Projects",
    finder = finders.new_table({ results = projects }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          M.open_project(selection.value)
        end
      end)

      map("n", "dd", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          M.remove_project(selection.value)
          M.open()
        end
      end)

      return true
    end,
  }):find()
end

function M.open()
  local projects = read_projects()

  if vim.tbl_isempty(projects) then
    vim.notify("No projects yet. Use :ProjectAdd or :ProjectAdd /path/to/project", vim.log.levels.WARN)
    return
  end

  select_project(projects)
end

local edit_state = {}

local function close_edit()
  if edit_state.win and vim.api.nvim_win_is_valid(edit_state.win) then
    vim.api.nvim_win_close(edit_state.win, true)
  end
  if edit_state.buf and vim.api.nvim_buf_is_valid(edit_state.buf) then
    vim.api.nvim_buf_delete(edit_state.buf, { force = true })
  end
  edit_state = {}
end

local function save_edit(buf)
  local next_projects = {}
  local seen = {}

  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    line = vim.trim(line)
    if line ~= "" then
      local path = normalize_path(line)
      if not seen[path] then
        seen[path] = true
        table.insert(next_projects, path)
      end
    end
  end

  write_projects(next_projects)
  vim.bo[buf].modified = false
  vim.notify("Projects saved")
end

function M.edit()
  if edit_state.win and vim.api.nvim_win_is_valid(edit_state.win) then
    close_edit()
    return
  end

  local projects = read_projects()
  local width = math.min(math.floor(vim.o.columns * 0.6), 100)
  local height = math.max(math.min(#projects + 2, math.floor(vim.o.lines * 0.6)), 8)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "projects-menu")
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "projects"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, projects)
  vim.bo[buf].modified = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    title = " Projects ",
    title_pos = "center",
    border = "rounded",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  })
  vim.wo[win].number = true

  edit_state = { buf = buf, win = win }

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      save_edit(buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(close_edit)
    end,
  })

  local opts = { buffer = buf, silent = true, nowait = true }

  vim.keymap.set("n", "q", close_edit, opts)
  vim.keymap.set("n", "<Esc>", close_edit, opts)

  vim.keymap.set("n", "<CR>", function()
    local line = vim.trim(vim.api.nvim_get_current_line())
    if line == "" then
      return
    end
    if vim.bo[buf].modified then
      save_edit(buf)
    end
    close_edit()
    M.open_project(line)
  end, opts)
end

function M.remove(path)
  if path and path ~= "" then
    M.remove_project(path)
    return
  end

  local projects = read_projects()

  if vim.tbl_isempty(projects) then
    vim.notify("No projects yet. Use :ProjectAdd or :ProjectAdd /path/to/project", vim.log.levels.WARN)
    return
  end

  select_project(projects)
end

function M.setup(opts)
  config = vim.tbl_extend("force", config, opts or {})
end

return M
