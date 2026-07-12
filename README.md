# mewrw

An **experimental**, modern, asynchronous file browser and remote file transfer plugin for Neovim, designed as a powerful and extensible replacement for the built-in `netrw`.

## Features

- **Asynchronous I/O**: All filesystem operations (local and remote) use non-blocking I/O (Libuv or jobstart), ensuring the UI remains perfectly responsive even during large transfers or archive indexing.
- **Unified Interface**: Same experience across Local FS, SFTP, and Archives (`.zip`, `.tar`, `.tar.gz`, `.tgz`, `.7z`).
- **Chained URIs**: Deeply nested navigation support using the `:::` separator (e.g., browsing a Zip file inside an SFTP server).
- **Clean Copy-Paste (Virtual Text)**: Icons and Git status indicators are rendered using Neovim's `extmarks` (virtual text). They are visible in the UI but **do not interfere with text selection or copying**.
- **Git Integration**:
  - Displays the current branch in the header.
  - Shows file status (`[M]`, `[A]`, `[?]`, etc.) at the end of the line.
  - **Directory Propagation**: If any file inside a directory is modified, the directory itself will show a `[M]` status.
- **Icon Support**: Choose between `none`, `emoji` (built-in, no extra font required), or `devicons` (requires `nvim-web-devicons`).
- **Target-Based Workflow**: Set a "Target Directory" once and perform Copy/Move operations from any other buffer with a single keypress.
- **Advanced Tree View**: Visual hierarchy with recursive expansion (`E`) and navigation.
- **Windows Friendly**: Full support for drive letters (e.g., `C:/`), network shares, and a virtual "This PC" root (`/`) to switch between drives.
- **Persistent Bookmarks**: Quickly save and recall locations via a persistent selection menu.
- **Batch Rename**: Integrated buffer-based batch renaming for multiple files or marked items.

## Screenshots

**View Modes**

| Default (List) | Detailed | Tree View |
| :---: | :---: | :---: |
| ![default](./image/1_default.png) | ![detail](./image/2_detail.png) | ![tree](./image/3_tree.png) |

**Icon Styles**

| None | Emoji (Built-in) | Devicons (Nerd Font) |
| :---: | :---: | :---: |
| ![none](./image/icons_none.png) | ![emoji](./image/icons_emoji.png) | ![devicons](./image/icons_devicons.png) |

**Advanced Features**

| Git Signs | Bookmarks | Batch Rename |
| :---: | :---: | :---: |
| ![gitsign](./image/icons_icons_with_gitsign.png) | ![bookmark](./image/4_bookmark.png) | ![batch_rename](./image/5_batch_rename.png) |

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "hdoi/mewrw.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- Optional: for 'devicons' mode
    config = function()
        require("mewrw").setup({
            icons = "emoji",            -- "none", "emoji", or "devicons"
            git_integration = true,      -- Enable git status and branch info
            default_view_mode = "list",  -- "list", "detailed", or "tree"
            debug = false,               -- Set to true to see verbose logs
        })
    end
}
```

## Usage

### Commands

| Command | Action |
| :--- | :--- |
| `:Mewrw [uri]` | Open explorer in the current window |
| `:MewrwV [uri]` | Open in a vertical split |
| `:MewrwH [uri]` | Open in a horizontal split |
| `:MewrwT [uri]` | Open in a new tab |

### URI Specification (Chaining)

`mewrw` uses `:::` to chain multiple actions or layers.

- **Local**: `/home/user/test.zip` (Linux) or `C:/test.zip` (Windows)
- **SFTP**: `sftp://user@host/path`
- **Chained Archive**:
  - Open local zip: `C:/test.zip:::zip://`
  - Open remote zip: `sftp://host/data.zip:::zip://`
  - Deep nesting: `sftp://host/backup.tar:::tar://nested.zip:::zip://`
- **Compressed Files**: `test.gz:::compress://` (displays the uncompressed file as a virtual entry)

## Key Mappings

### Navigation & Files
| Key | Action |
| :--- | :--- |
| `<CR>` | Open file (edit) or enter directory / archive |
| `p` | Quick preview in a right pane (Focus stays in explorer) |
| `x` | Open file/directory with external application |
| `-` / `<BS>` | Go up to parent directory (Exits archives to the host folder) |
| `R` | Reload/Refresh current view |
| `?` | Live filter entries in the current view |
| `u` | Show help (Mewrw manual) |

### View Options
| Key | Action |
| :--- | :--- |
| `i` | Cycle View Mode (List → Detailed → Tree) |
| `a` | Toggle display of Hidden files (dotfiles) |
| `A` | Toggle display of Full Path for entries |
| `s` | Cycle Sort Type (Name → Numerical → Extension → Size → Mtime) |
| `S` | Toggle Sort Order (Ascending / Descending) |
| `C` | **Tree Mode**: Collapse all expanded nodes |
| `E` | **Tree Mode**: Expand one level for all currently visible directories |

### Marks & Operations
| Key | Action |
| :--- | :--- |
| `mf` | Toggle mark for item under cursor (Supports **Visual Mode**) |
| `mt` | Clear all current marks |
| `ma` | Show a list of all currently marked items |
| `TT` | Set current directory as **Global Target** |
| `Tc` | Copy marked items to **Global Target** |
| `Tm` | Move marked items to **Global Target** |
| `D` | Delete item under cursor or marked items (Supports **Visual Mode**) |
| `r` | Rename item under cursor |
| `mr` | Batch rename marked items (Supports **Visual Mode**) |
| `d` | Create a new directory |

### Bookmarks
| Key | Action |
| :--- | :--- |
| `m` | Add current directory to bookmarks |
| `b` | List and jump to a bookmark |
| `B` | Select and remove a bookmark |

## Requirements

- Neovim 0.8+
- **For SFTP**: `sftp` and `ssh` commands.
- **For Archives**: `zip`, `unzip`, `7z` or `tar` (standard on Windows 10+ / Linux).
- **For Icons**: `nvim-web-devicons` (optional).

## License

MIT
