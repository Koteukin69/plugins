if vim.g.loaded_lang_nvim == 1 then
  return
end
vim.g.loaded_lang_nvim = 1

local lang = require("lang")

vim.api.nvim_create_user_command("LangLayoutUpdate", function()
  lang.update()
end, { desc = "Update keyboard layout status" })

vim.api.nvim_create_user_command("LangLayoutStart", function()
  lang.start_monitor()
end, { desc = "Start keyboard layout monitor" })

vim.api.nvim_create_user_command("LangLayoutStop", function()
  lang.stop_monitor()
end, { desc = "Stop keyboard layout monitor" })
