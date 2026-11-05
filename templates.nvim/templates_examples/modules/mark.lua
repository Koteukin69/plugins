local function setMark(name, position)
  local bufnr = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_mark(bufnr, name, position.row + 1, position.col, {})
end

local function mark(props, position)
  local key = props.key or "1"

  setMark(key, position)
end

return mark
