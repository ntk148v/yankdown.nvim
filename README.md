# yankdown.nvim

Smart paste for Markdown in Neovim.

When invoked in a Markdown buffer, `yankdown.nvim` reads HTML from the system clipboard, converts it to GitHub Flavored Markdown with `pandoc`, and inserts the result. If HTML is unavailable or a required tool is missing, it falls back to native paste.

## Requirements

- Neovim 0.10+
- `pandoc`
- One clipboard HTML provider:
  - macOS: `osascript`
  - Wayland: `wl-paste`
  - X11: `xclip`

Windows clipboard HTML is not supported in v1.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ntk148v/yankdown.nvim",
  opts = {}  -- calls setup() for you
}
```

## Setup

```lua
require("yankdown").setup({
  auto_intercept = false,
  notify = true,
})
```

## Usage

Command:

```vim
:YankdownPaste
:YankdownPaste!
```

Lua:

```lua
require("yankdown").paste({ direction = "after" })
require("yankdown").paste({ direction = "before" })
```

Mappings:

```lua
vim.keymap.set({ "n", "x", "i" }, "<leader>p", function()
  require("yankdown").paste({ direction = "after" })
end)
```

Plug mappings:

```vim
<Plug>(yankdown-paste-after)
<Plug>(yankdown-paste-before)
```

## Optional paste interception

```lua
require("yankdown").setup({
  auto_intercept = true,
})
```

This creates Markdown-buffer-local mappings for `p` and `P`. It does not create global mappings.

## Fallback behavior

Native paste is used when:

- the current buffer is not Markdown
- the clipboard has no HTML payload
- the platform/provider is unsupported
- the clipboard tool is missing
- `pandoc` is missing or conversion fails
