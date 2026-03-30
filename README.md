# mewrw

A modern, asynchronous file browser and remote file transfer plugin for Neovim, designed as a powerful and extensible replacement for the built-in `netrw`.

## Features

- **Asynchronous I/O**: All filesystem operations (local and remote) use non-blocking I/O (Libuv or jobstart), ensuring the UI remains perfectly responsive even during large transfers or archive indexing.
- **Unified Interface**: Same experience across Local FS, SFTP, and Archives (`.zip`, `.tar`).
- **Clean Copy-Paste (Virtual Text)**: Icons and Git status indicators are rendered using Neovim's `extmarks` (virtual text). They are visible in the UI but **do not interfere with text selection or copying**—when you yank a line or copy with a mouse, you get only the clean filename/path.
- **Git Integration**:
  - Displays the current branch in the header.
  - Shows file status (`[M]`, `[A]`, `[?]`, etc.) at the end of the line.
  - **Directory Propagation**: If any file inside a directory is modified, the directory itself will show a `[M]` status.
- **Icon Support**: Choose between `none`, `emoji` (built-in, no extra font required), or `devicons` (requires `nvim-web-devicons`).
- **Global Mark Management**: Mark items across different directories or windows. Selection is shared globally.
- **Target-Based Workflow**: Set a "Target Directory" once and perform Copy/Move operations from any other buffer with a single keypress.
- **Advanced Tree View**: Visual hierarchy with recursive expansion (`E`) and navigation.
- **Persistent Bookmarks**: Quickly save and recall locations via a persistent selection menu.

### screenshot

**View mode**

| Default  | Detail | Tree |
| :---: | :---: |:---: |
| ![default](./image/1_default.png)  | ![detail](./image/2_detail.png) | ![tree](./image/3_tree.png) |

**Icons**

| None | Emoji | Devicons | 
| :---: | :---: | :---: |
| ![none](./image/icons_none.png) | ![emoji](./image/icons_emoji.png) | ![devicons](./image/icons_devicons.png) |

**Other Features**

| Git sign | bookmark | Batch rename | 
| :---: | :---: | :---: |
| ![gitsign](./image/icons_icons_with_gitsign.png) | ![bookmark](./image/4_bookmark.png) | ![batch_rename](./image/5_batch_rename.png) |

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "hdoi/mewrw",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- Optional: for 'devicons' mode
    config = function()
        require("mewrw").setup({
            icons = "emoji",            -- "none", "emoji", or "devicons"
            git_integration = true,      -- Enable git status and branch info
            default_view_mode = "list",  -- "list", "detailed", or "tree"
        })
    end
}
```

## Usage

Start the plugin with the command:
```vim
:Mewrw [uri]   " Open in current window
:MewrwV [uri]  " Open in vertical split
:MewrwH [uri]  " Open in horizontal split
:MewrwT [uri]  " Open in new tab
```
If no URI is provided, it opens the current working directory. Supported schemes: `sftp://`, `zip://`, `tar://`.

## Configuration

Default options:
```lua
require("mewrw").setup({
    default_view_mode = "list", -- "list", "detailed", or "tree"
    show_hidden = false,        -- Show dotfiles by default
    sort_by = "name",           -- "name", "numerical", "size", "mtime", "extension"
    sort_reverse = false,       -- Reverse the sort order
    icons = "none",             -- "none", "emoji", or "devicons"
    git_integration = false,    -- Set to true to enable Git status/branch
})
```

## Key Mappings

Press `u` within any `mewrw` buffer to see the interactive help popup.

| Key | Action |
| :--- | :--- |
| `<CR>` | Open file (edit) or enter directory |
| `-` / `<BS>` | Go up to parent directory |
| `R` | Reload/Refresh current view |
| `i` | Cycle View Mode (List → Detailed → Tree) |
| `a` | Toggle display of Hidden files (dotfiles) |
| `?` | Live filter entries in the current view |
| `mf` | Toggle mark (supports Visual mode) |
| `TT` | Set current directory as **Global Target** |
| `Tc` | Copy marked items to **Global Target** |
| `Tm` | Move marked items to **Global Target** |

## Requirements

- Neovim 0.8+
- **For SFTP**: `sftp` command.
- **For Archives**: `zip`, `unzip`, and `tar` commands.
- **For Icons**: `nvim-web-devicons` (optional, only for `icons = "devicons"`).

## License

MIT
