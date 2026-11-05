local M = {}

local defaults = {
  keyword = "<leader>m",
  snippets_path = "~/.config/nvim/templates/snippets",
  components_path = "~/.config/nvim/templates/components/",
  modules_path = "~/.config/nvim/templates/modules/",
}

M.templates = require("templates")

--- @type table<integer, string[]>
local bound_keys = {}

local function getSnippets(path)
  -- TODO: Реализовать парсинг сниппетов
  return require("templates.snippets")
end

local function insert_text(text)
  local lines = vim.split(text, "\n", { plain = true })
  vim.api.nvim_put(lines, "c", true, true)
end

local function bind_snippets(bufnr, opts)
  if bound_keys[bufnr] then
    return
  end

  local snippets = getSnippets("")
  local keys = {}

  for _, snip in ipairs(snippets) do
    local lhs = opts.keyword .. snip.key
    vim.keymap.set("n", lhs, function()
      insert_text(snip.text)
    end, { buffer = bufnr, silent = true })
    table.insert(keys, lhs)
  end

  bound_keys[bufnr] = keys
end

local function unbind_snippets(bufnr)
  local keys = bound_keys[bufnr]
  if not keys then
    return
  end

  for _, lhs in ipairs(keys) do
    pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
  end

  bound_keys[bufnr] = nil
end

function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("templates.nvim", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      bind_snippets(args.buf, opts)
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      unbind_snippets(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      bound_keys[args.buf] = nil
    end,
  })

  bind_snippets(vim.api.nvim_get_current_buf(), opts)
end

return M
