# projects.nvim

Small Neovim project switcher.

## Installation

With `lazy.nvim`:

```lua
{
  dir = "/data/plugins/projects.nvim",
  name = "projects.nvim",
  config = function()
    require("projects").setup()
  end,
}
```

If the plugin is loaded normally, commands are registered automatically.

## Commands

```vim
:ProjectAdd
:ProjectAdd /path/to/project
:ProjectOpen
:ProjectEdit
:ProjectRemove
:ProjectRemove /path/to/project
```

`ProjectEdit` opens the project list in a floating window as an editable buffer (like harpoon's quick menu). One line is one project: delete lines with `dd`, reorder them with `dd`/`p`, or edit paths directly. `:w` saves the list, `<CR>` opens the project under the cursor, `q`/`<Esc>` closes the window. Unsaved changes are discarded on close.

`ProjectAdd` stores the current directory or the provided directory in `stdpath("data") .. "/projects.json"`.

`ProjectOpen` opens a Telescope project picker. Press Enter to open a project or `dd` in normal mode to remove it.

`ProjectRemove` removes a project by path or opens the project picker when no path is provided.

## Configuration

```lua
require("projects").setup({
  file = vim.fn.stdpath("data") .. "/projects.json",
  nvim_tree = true,
})
```
