# yankdown.nvim

Smart paste for Markdown in Neovim — paste rich content from browsers, Google Docs, or Word as clean GitHub Flavored Markdown.

When invoked in a Markdown buffer, `yankdown.nvim` reads HTML from the system clipboard, converts it to GFM via `pandoc`, and inserts the result at the cursor. If HTML is unavailable or a required tool is missing, it falls back to native paste transparently.

## How it works

```
Clipboard has HTML?  ─yes→  pandoc converts to GFM  ─→  Insert Markdown
       │                                                   │
      no                                                   no
       ↓                                                    ↓
  Native paste                                    Native paste
```

1. Check current buffer — only activates for `filetype=markdown`
2. Query clipboard provider for `text/html` (async)
3. Pipe HTML through `pandoc -f html -t markdown_strict+gfm_markdown_blocks+pipe_tables --wrap=none`
4. Insert converted Markdown respecting current mode (normal after/before, visual replace, insert at cursor)

## Requirements

- Neovim 0.10+ (uses `vim.system` for async shell calls)
- [pandoc](https://pandoc.org/) — HTML to Markdown conversion engine
- One clipboard HTML provider:

| Platform | Tool                             |
| -------- | -------------------------------- |
| macOS    | `osascript` (built-in)           |
| Wayland  | `wl-paste` (from `wl-clipboard`) |
| X11      | `xclip`                          |

Windows clipboard HTML is not supported in v1.

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ntk148v/yankdown.nvim",
  opts = {},  -- calls setup() for you
}
```

Or with any plugin manager:

```vim
" vim-plug
Plug 'ntk148v/yankdown.nvim'

" packer.nvim
use 'ntk148v/yankdown.nvim'
```

## Setup

```lua
require("yankdown").setup({
  auto_intercept = false,  -- override p/P in markdown buffers
  notify = true,           -- warn once on missing tools/conversion failure
})
```

### Options

| Key              | Default | Description                                                                   |
| ---------------- | ------- | ----------------------------------------------------------------------------- |
| `auto_intercept` | `false` | When true, maps `p` and `P` to smart paste in Markdown buffers only.          |
| `notify`         | `true`  | Show a one-time `vim.notify` warning on missing tools or conversion failures. |

## Usage

### Command

```vim
:YankdownPaste      " paste after cursor
:YankdownPaste!     " paste before cursor
```

### Lua

```lua
require("yankdown").paste({ direction = "after" })
require("yankdown").paste({ direction = "before" })
```

### Keymaps

```lua
vim.keymap.set({ "n", "x", "i" }, "<leader>p", function()
  require("yankdown").paste({ direction = "after" })
end)
```

Plug mappings are also available:

```vim
:map <leader>p <Plug>(yankdown-paste-after)
:map <leader>P <Plug>(yankdown-paste-before)
```

### Optional paste interception

Enable automatic interception of `p` and `P` in Markdown buffers:

```lua
require("yankdown").setup({
  auto_intercept = true,
})
```

This creates **buffer-local** mappings only for Markdown filetype. No global keys are modified.

## Fallback behavior

Native paste (as if yankdown.nvim were not installed) is used when:

- The current buffer is not Markdown
- The clipboard has no HTML payload (silent, no notification)
- The platform/provider is unsupported (warn once if `notify = true`)
- The clipboard tool is missing (warn once if `notify = true`)
- `pandoc` is missing or conversion fails (warn once if `notify = true`)

## Limitations (v1)

- Windows clipboard HTML is not supported
- No built-in HTML-to-Markdown converter (depends on `pandoc`)
- Does not support paste counts or explicit register selection — those use the native fallback path automatically
