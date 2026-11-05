if vim.g.loaded_projects_nvim then
  return
end

vim.g.loaded_projects_nvim = true

vim.api.nvim_create_user_command("ProjectAdd", function(command)
  require("projects").add(command.args)
end, {
  nargs = "*",
  complete = "dir",
})

vim.api.nvim_create_user_command("ProjectOpen", function()
  require("projects").open()
end, {})

vim.api.nvim_create_user_command("ProjectEdit", function()
  require("projects").edit()
end, {})

vim.api.nvim_create_user_command("ProjectRemove", function(command)
  require("projects").remove(command.args)
end, {
  nargs = "*",
  complete = "dir",
})
